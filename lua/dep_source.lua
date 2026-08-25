--------------------------------------------------------------------------------
-- Jump into dependency sources -- the Android-Studio equivalent, on demand.
--
-- Why this exists: kotlin-language-server cannot go-to-definition into library
-- symbols on a Gradle project. Its ClassPathEntry has a sourceJar slot, but only
-- MavenClassPathResolver ever fills it -- GradleClassPathResolver delegates
-- getClasspathWithSources() to the interface default, which is just
-- getClasspath(). So every entry in kls_database.db carries sourceJar = NULL and
-- the server has no source location to jump to.
--
-- This reproduces what Android Studio does, using the same pieces:
--   * locate the class in the compile classpath  (IntelliJ: project model)
--   * read the entry straight out of the jar     (IntelliJ: JarFileSystem)
--   * fetch a missing sources jar from Gradle    (IntelliJ: "Download Sources")
--
-- Strictly on demand: nothing is pre-fetched, pre-extracted or pre-indexed. Only
-- the one library you actually jumped into gets touched, and sources jars land in
-- ~/.gradle/caches/modules-2 -- the same place Android Studio reads and writes,
-- so the two never keep duplicate copies.
--
-- Version correctness is the subtle part. A class name alone is not enough: this
-- cache holds many historical versions of the same library (AppPageType.kt lives
-- in a dozen bluetooth-*-sources.jar files). Resolving by class name picks an
-- arbitrary one and shows you code that is not what compiles. So the compiled jar
-- on the *current* classpath is located first, and its exact version drives the
-- sources lookup.
--------------------------------------------------------------------------------

local M = {}

local KLS_DB = "kls_database.db"
local ROOT_MARKERS = { "settings.gradle", "settings.gradle.kts", "gradlew", ".git" }

--- Matches the line that *declares* a type, in Vim's very-magic syntax.
--- Used to place the cursor: searching for the bare word lands in whichever KDoc
--- block mentions it first, which in a 700-line file like the stdlib's
--- Collections.kt is 500 lines away from the actual declaration.
local function declaration_pattern(symbol)
  return "\\v^\\s*(public |internal )?(expect |actual )?"
    .. "(sealed |abstract |open |annotation |data |value )?"
    .. "(interface|class|object|enum class|typealias) "
    .. vim.fn.escape(symbol, "\\/.*$^~[]")
    .. "[<( :{]"
end

--- Regex (ERE, for ripgrep) matching the line that declares `symbol`, whether it
--- is a type or a function.
---
--- Functions need more shapes than types do. Kotlin puts generics after `fun`, an
--- extension function carries a receiver before the name, and a body may open
--- with `{` or `=`:
---   public inline fun <R> runCatching(block: () -> R): Result<R> {
---   public inline fun <T, R> T.runCatching(block: T.() -> R): Result<R> {
---   public fun <T> emptyList(): List<T> = EmptyList
local function declaration_search_regex(symbol)
  return "(interface|class|object|enum class|typealias|fun) "
    .. "(<[^>]*> )?" -- generic parameters
    .. "([A-Za-z0-9_.<>?]+\\.)?" -- extension receiver
    .. symbol
    .. "[<(: {=]"
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "dep-source" })
end

local function project_root()
  -- A chained jump starts from a cached library file, which lives under
  -- stdpath("cache") and therefore has no build markers above it. Carry the root
  -- forward on the buffer instead of trying to re-derive it from the path.
  if vim.b.dep_source_root then
    return vim.b.dep_source_root
  end
  return vim.fs.root(0, ROOT_MARKERS) or vim.fn.getcwd()
end

--- Prepare a freshly opened library-source buffer.
---
--- `gd` is bound buffer-locally here because the global mapping lives in an
--- LspAttach handler, and no server attaches to a file outside the project tree.
--- Without this, jumping from one library symbol to another silently falls back
--- to Vim's builtin `gd` (local declaration search) and appears to do nothing.
local function setup_dep_buffer(root, symbol, member)
  vim.b.dep_source_root = root

  -- Library sources are for reading; guard against edits that go nowhere.
  vim.bo.readonly = true
  vim.bo.modifiable = false

  local function jump()
    M.goto_dependency_source()
  end
  vim.keymap.set("n", "gd", jump, { buffer = 0, desc = "go to dependency source" })
  vim.keymap.set("n", "<C-]>", jump, { buffer = 0, desc = "go to dependency source" })

  -- A method jump should land on the method, not on the enclosing type. Same
  -- shapes as the search regex, expressed in Vim's very-magic syntax, plus a Java
  -- signature form and a bare-word last resort.
  if member then
    local m = vim.fn.escape(member, "\\/.*$^~[]")
    for _, pat in ipairs {
      "\\v(fun) (\\<[^>]*\\> )?([A-Za-z0-9_.<>?]+\\.)?" .. m .. "[<(: {=]",
      "\\v^\\s*(\\w+|\\<[^>]+\\>|\\[\\])+\\s+" .. m .. "\\s*\\(",
      "\\v<" .. m .. ">",
    } do
      if vim.fn.search(pat, "cw") > 0 then
        return
      end
    end
  end

  if symbol then
    -- Declaration first; only fall back to a plain word match if the type is
    -- declared in some form this pattern does not cover.
    if vim.fn.search(declaration_pattern(symbol), "cw") == 0 then
      vim.fn.search(("\\<%s\\>"):format(vim.fn.escape(symbol, "\\/")), "cw")
    end
  end
end

--- Fully-qualified name of the symbol under the cursor.
--- Resolved from the buffer's own import list rather than from the LSP, because
--- the whole point is that the LSP has no location for this symbol.
---@return string? fqn    the type to open
---@return string? symbol the type's name
---@return string? member a method to land on inside it, when the cursor was on one
local function fqn_under_cursor()
  local word = vim.fn.expand("<cword>")
  if word == "" then
    return nil, nil, nil
  end

  local imports, star_prefixes = {}, {}
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    local imported = line:match("^%s*import%s+([%w_.]+)")
    if imported then
      local last = imported:match("([%w_]+)$")
      if last then
        imports[last] = imported
      end
      local prefix = imported:match("^([%w_.]+)%.%*$")
      if prefix then
        table.insert(star_prefixes, prefix)
      end
    end
    -- Imports are always above the first declaration; no need to scan further.
    if line:match("^%s*class%s") or line:match("^%s*object%s") or line:match("^%s*interface%s") then
      break
    end
  end

  -- The word itself is imported: a type, or a top-level/extension function.
  if imports[word] then
    return imports[word], word, nil
  end

  -- Something dotted precedes the cursor. Two very different cases share this
  -- shape, told apart by the case of the last segment:
  --   HeartRateActivity.launch  -- imported type, `launch` is a member
  --   kotlin.runCatching        -- package prefix, `runCatching` is top-level
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local qualifier = line:sub(1, col + 1):match("([%w_.]+)%s*%.%s*[%w_]*$")
  if qualifier then
    local last = qualifier:match("([%w_]+)$")
    if last and imports[last] then
      return imports[last], last, word
    end
    -- Lowercase last segment means a package, by universal convention.
    if last and last:match("^%l") then
      return qualifier .. "." .. word, word, nil
    end
  end

  for _, prefix in ipairs(star_prefixes) do
    return prefix .. "." .. word, word, nil
  end

  -- Same-package reference: fall back to this file's own package.
  local pkg
  for _, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, 20, false)) do
    pkg = l:match("^%s*package%s+([%w_.]+)")
    if pkg then
      break
    end
  end
  if pkg then
    return pkg .. "." .. word, word, nil
  end

  return nil, word, nil
end

--- Every compiled jar on the current classpath, as recorded by kls.
local function classpath_jars(root)
  local db = root .. "/" .. KLS_DB
  if vim.fn.filereadable(db) == 0 then
    return nil, ("%s not found -- open a Kotlin buffer once so kls builds it"):format(KLS_DB)
  end

  local out = vim
    .system({
      "sqlite3",
      db,
      "select compiledjar from ClassPathCacheEntry",
    }, { text = true })
    :wait()

  if out.code ~= 0 then
    return nil, "could not read " .. KLS_DB
  end

  return vim.split(vim.trim(out.stdout or ""), "\n", { trimempty = true })
end

--- Find which jar in `jars` contains `class_path`.class, scanning in parallel.
local function jar_containing(jars, class_path)
  local script = ([[
printf '%%s\n' "$@" | xargs -P 8 -I{} sh -c '
  unzip -l "$1" 2>/dev/null | grep -q "%s\.class$" && echo "$1"
' _ {} 2>/dev/null | head -1
]]):format(vim.pesc(class_path):gsub("%%", "%%%%"))

  local cmd = { "sh", "-c", script, "sh" }
  vim.list_extend(cmd, jars)

  local out = vim.system(cmd, { text = true }):wait()
  local hit = vim.trim(out.stdout or "")

  return hit ~= "" and hit or nil
end

--- Maven-style base name of a compiled jar: the artifact-version pair that a
--- sibling sources jar is named after.
--- AGP rewrites AAR classes into `jetified-<artifact>-<version>-{api,runtime}.jar`.
--- Returns nil when the jar is not a resolvable Maven artifact at all, so the
--- caller can skip a multi-minute Gradle round trip that could never succeed.
local function sources_basename(jar)
  local name = vim.fn.fnamemodify(jar, ":t")
  -- `classes.jar` is the generic name AGP gives an exploded AAR; it carries no
  -- coordinate, so the version cannot be recovered from it.
  if name == "classes.jar" then
    return nil
  end

  local base = (
    name
      :gsub("^jetified%-", "")
      :gsub("%-api%.jar$", "")
      :gsub("%-runtime%.jar$", "")
      :gsub("%.jar$", "")
  )

  -- A Maven artifact always carries a version. Without one this is an SDK or
  -- build-generated jar -- android.jar, R.jar, core-lambda-stubs -- which no
  -- repository will ever serve sources for.
  if not base:match("%-%d") then
    return nil
  end

  return base
end

local function find_sources_jar(basename)
  local matches = vim.fs.find(basename .. "-sources.jar", {
    path = vim.fn.expand("~/.gradle/caches/modules-2"),
    type = "file",
    limit = 1,
  })
  return matches[1]
end

--- Source file for a class that lives in the Android SDK's android.jar.
---
--- The SDK ships sources as plain files under `sources/android-<api>/`, so there
--- is nothing to unzip -- but android.jar carries no version in its name, so the
--- Maven path cannot resolve it. The API level comes from the jar's own directory
--- (`platforms/android-36/android.jar`).
---
--- Directory names do not always match the platform exactly: a platform of
--- `android-36` may ship its sources as `android-36.1`. So the exact level is
--- tried first, then any directory whose level starts with it, then the highest
--- available -- an older SDK's sources are still far more useful than none.
local function android_sdk_source(compiled_jar, class_path)
  local sdk_root, api = compiled_jar:match("^(.*)/platforms/android%-([%w%.]+)/android%.jar$")
  if not sdk_root then
    return nil
  end

  local candidates = {}
  for name, kind in vim.fs.dir(sdk_root .. "/sources") do
    if kind == "directory" and name:match("^android%-") then
      table.insert(candidates, name)
    end
  end

  -- Exact, then same-major (36 -> 36.1), then newest first.
  table.sort(candidates, function(a, b)
    local function rank(n)
      local level = n:match("^android%-(.+)$") or ""
      if level == api then
        return -math.huge
      end
      if level:match("^" .. vim.pesc(api)) then
        return -1e308
      end
      return -(tonumber(level:match("^(%d+)")) or 0)
    end
    return rank(a) < rank(b)
  end)

  for _, name in ipairs(candidates) do
    local path = ("%s/sources/%s/%s.java"):format(sdk_root, name, class_path)
    if vim.uv.fs_stat(path) then
      return path, name
    end
  end
end

--- Locate the entry that *declares* `symbol`, when its path cannot be derived.
---
--- Two cases need this. Kotlin does not tie a file name to the types inside it,
--- so a library may declare `Foo` in `Bar.kt`. And Kotlin's builtins are worse:
--- `kotlin.collections.MutableMap` is declared in `commonMain/kotlin/Collections.kt`
--- -- neither the package path nor the file name matches, and there is no
--- MutableMap.class at all because the compiler maps it onto java.util.Map.
---
--- Extract-then-ripgrep rather than zipgrep: macOS's zipgrep is a shell script
--- that mangles any pattern containing spaces or brackets (a bare `interface Foo`
--- matches, but adding `[<( :{]` silently yields nothing), and it is ~10x slower.
--- Sources jars are small -- the stdlib is 732 KB -- so unpacking to a temp dir
--- costs ~100 ms and gives a real regex engine.
local function find_entry_by_declaration(sources_jar, symbol)
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")

  local unpacked = vim
    .system({ "unzip", "-o", "-q", sources_jar, "*.kt", "*.java", "-d", tmp }, { text = true })
    :wait()

  local hits = {}
  if unpacked.code == 0 or vim.fn.isdirectory(tmp) == 1 then
    local pattern = declaration_search_regex(symbol)

    local searcher = vim.fn.executable("rg") == 1
        and { "rg", "-l", "--no-messages", "-e", pattern, tmp }
      or { "grep", "-rlE", pattern, tmp }

    local out = vim.system(searcher, { text = true }):wait()
    for _, line in ipairs(vim.split(vim.trim(out.stdout or ""), "\n", { trimempty = true })) do
      -- Back to a jar-relative entry path.
      table.insert(hits, (line:gsub("^" .. vim.pesc(tmp) .. "/", "")))
    end
  end

  vim.fn.delete(tmp, "rf")

  -- Prefer the common source set: for a multiplatform declaration that is where
  -- the documented `expect` sits, while jvmMain holds the mechanical `actual`.
  table.sort(hits, function(a, b)
    local function rank(p)
      return p:match("^commonMain/") and 1 or (p:match("^jvmMain/") and 2 or 3)
    end
    return rank(a) < rank(b)
  end)

  return hits[1]
end

--- The Kotlin standard library on this classpath, as a sources jar.
--- Needed because stdlib symbols usually appear with no import at all -- they are
--- default-imported -- so there is no FQN to resolve a jar from.
local function stdlib_sources_jar(jars)
  for _, jar in ipairs(jars) do
    local base = vim.fn.fnamemodify(jar, ":t"):match("^(kotlin%-stdlib%-[%d%.]+)%.jar$")
    if base then
      return find_sources_jar(base)
    end
  end
end

--- Find the jar that owns a package, rather than a specific class.
---
--- Top-level and extension functions have no class of their own: Kotlin compiles
--- them into `<FileName>Kt.class`, named after the *file*, which cannot be derived
--- from the function's fully-qualified name. The package still pins down the jar,
--- and a declaration search inside it does the rest.
local function jar_containing_package(jars, pkg_path)
  local script = ([[
printf '%%s\n' "$@" | xargs -P 8 -I{} sh -c '
  unzip -l "$1" 2>/dev/null | grep -qE " %s/[^/]+\.class$" && echo "$1"
' _ {} 2>/dev/null | head -1
]]):format(vim.pesc(pkg_path):gsub("%%", "%%%%"))

  local cmd = { "sh", "-c", script, "sh" }
  vim.list_extend(cmd, jars)

  local out = vim.system(cmd, { text = true }):wait()
  local hit = vim.trim(out.stdout or "")

  return hit ~= "" and hit or nil
end

--- Ask Gradle for one library's sources jar -- the same ArtifactResolutionQuery
--- that Android Studio's "Download Sources" runs. Async: a cold Gradle
--- configuration on a large project takes minutes.
local function fetch_sources(root, basename, on_done)
  local script = root .. "/.dep-source-fetch.gradle"
  local body = ([[
import org.gradle.jvm.JvmLibrary
import org.gradle.language.base.artifact.SourcesArtifact
allprojects { project ->
    task depSourceFetch {
        doLast {
            def cfgs = project.configurations.findAll {
                it.name.toLowerCase().endsWith('compileclasspath') && !it.name.contains('Test')
            }
            def wanted = '%s'
            def ids = []
            cfgs.each { cfg ->
                try {
                    cfg.incoming.resolutionResult.allDependencies
                        .findAll { it.hasProperty('selected') }
                        .collect { it.selected.id }
                        .findAll { it.class.name.contains('ModuleComponentIdentifier') }
                        .each { id ->
                            if ((id.module + '-' + id.version) == wanted) { ids << id }
                        }
                } catch (Exception ignored) { }
            }
            if (ids.isEmpty()) { println "DEPSRC no-component"; return }
            def q = project.dependencies.createArtifactResolutionQuery()
                .forComponents(ids.unique { it.toString() })
                .withArtifacts(JvmLibrary, SourcesArtifact)
                .execute()
            int got = 0
            q.resolvedComponents.each { c ->
                c.getArtifacts(SourcesArtifact).each { a ->
                    if (a.hasProperty('file')) { println "DEPSRC got " + a.file; got++ }
                }
            }
            if (got == 0) println "DEPSRC none-published"
        }
    }
}
]]):format(basename)

  vim.fn.writefile(vim.split(body, "\n"), script)
  notify("fetching sources for " .. basename .. " (Gradle, may take a while)")

  vim.system({
    "./gradlew",
    "--init-script",
    script,
    "-q",
    "depSourceFetch",
  }, { cwd = root, text = true }, function(res)
    vim.schedule(function()
      os.remove(script)
      if (res.stdout or ""):match("DEPSRC none%-published") then
        on_done(nil, basename .. ": no sources published by the repository")
      elseif res.code ~= 0 then
        on_done(nil, "Gradle failed: " .. vim.trim((res.stderr or ""):sub(1, 200)))
      else
        on_done(find_sources_jar(basename))
      end
    end)
  end)
end

--- Materialise one jar entry under the cache dir and open it normally.
---
--- An earlier version built a scratch buffer and pushed the lines in directly.
--- That fought Neovim rather than using it: naming a buffer `depsrc://...` and
--- setting its filetype fires the usual autocmds against a buffer that has no
--- file behind it, and the whole thing has to happen outside a fast event
--- context. Writing a real file and letting `:edit` do its job restores every
--- normal behaviour -- jumplist, `<C-o>`, search, syntax, session reload -- for
--- the price of a few KB. This is also exactly what kls does for android.jar.
---
--- The path mirrors the jar's internal layout so two classes with the same name
--- from different libraries never collide, and a second jump is a plain file open.
local function open_in_jar(jar, entry, symbol, root, member)
  local artifact = vim.fn.fnamemodify(jar, ":t"):gsub("%-sources%.jar$", "")
  local dir = vim.fn.stdpath("cache") .. "/dep-source/" .. artifact
  local path = dir .. "/" .. entry

  if vim.fn.filereadable(path) == 0 or vim.fn.getfsize(path) <= 0 then
    local out = vim.system({ "unzip", "-p", jar, entry }, { text = true }):wait()
    if out.code ~= 0 or vim.trim(out.stdout or "") == "" then
      notify(
        ("could not read %s from %s"):format(entry, vim.fn.fnamemodify(jar, ":t")),
        vim.log.levels.ERROR
      )
      return
    end

    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    local lines = vim.split(out.stdout, "\n")
    -- unzip's trailing newline turns into a phantom last line.
    if lines[#lines] == "" then
      table.remove(lines)
    end
    vim.fn.writefile(lines, path)
  end

  vim.cmd.edit(vim.fn.fnameescape(path))
  setup_dep_buffer(root, symbol, member)

  notify(("%s  (%s)"):format(entry:match("[^/]+$"), artifact))

  return path
end

--------------------------------------------------------------------------------
-- Resolution index.
--
-- Locating which jar holds a class means unzip -l over every classpath entry --
-- ~1.8s for 825 jars even at 8-way parallelism. That answer is stable as long as
-- the dependency stays at the same version, so it is worth persisting: a repeat
-- jump costs one sqlite read instead.
--
-- Keyed by FQN, and validated before use -- the recorded jar must still be on the
-- current classpath. That check is what keeps a version bump from silently
-- serving last week's source, which is the whole reason this resolves through the
-- compiled jar rather than by class name in the first place.
--------------------------------------------------------------------------------

local INDEX_FILE = vim.fn.stdpath("cache") .. "/dep-source/index.json"

local function read_index()
  if vim.fn.filereadable(INDEX_FILE) == 0 then
    return {}
  end
  local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(INDEX_FILE), "\n"))
  return (ok and type(data) == "table") and data or {}
end

local function write_index(index)
  vim.fn.mkdir(vim.fn.fnamemodify(INDEX_FILE, ":h"), "p")
  pcall(vim.fn.writefile, { vim.json.encode(index) }, INDEX_FILE)
end

--- Open an already-materialised source file.
local function open_cached(path, symbol, root, member)
  vim.cmd.edit(vim.fn.fnameescape(path))
  setup_dep_buffer(root, symbol, member)
end

--- Entry point: jump to the source of the dependency symbol under the cursor.
function M.goto_dependency_source()
  local fqn, symbol, member = fqn_under_cursor()
  if not fqn then
    notify("no symbol under cursor", vim.log.levels.WARN)
    return
  end

  local class_path = fqn:gsub("%.", "/")
  local root = project_root()

  local jars, err = classpath_jars(root)
  if not jars then
    notify(err, vim.log.levels.ERROR)
    return
  end

  local index = read_index()
  local cached = index[fqn]

  -- Fast path: known FQN, source already on disk, and the jar it came from is
  -- still the one on the classpath.
  if
    cached
    and cached.file
    and vim.fn.getfsize(cached.file) > 0
    and cached.jar
    and vim.tbl_contains(jars, cached.jar)
  then
    open_cached(cached.file, symbol, root, member)
    return
  end

  notify(("resolving %s across %d classpath entries"):format(fqn, #jars))

  local compiled = jar_containing(jars, class_path)

  -- No .class anywhere means one of two things: the symbol is default-imported
  -- (so the FQN guessed from this file's package is wrong), or it is a Kotlin
  -- builtin that has no class file at all. Both land in the standard library.
  if not compiled then
    -- No .class under this FQN. Three reasons, tried in order of specificity:
    --   1. a top-level or extension function -- compiled into <FileName>Kt.class,
    --      a name that cannot be derived from the FQN, but the package still
    --      identifies the jar;
    --   2. a default-imported symbol, so the FQN guessed from this file's own
    --      package is simply wrong;
    --   3. a Kotlin builtin, which has no class file anywhere.
    -- The last two both resolve inside the standard library.
    local pkg_path = class_path:match("^(.+)/[^/]+$")
    local owner = pkg_path and jar_containing_package(jars, pkg_path)
    local owner_base = owner and sources_basename(owner)
    local owner_sources = owner_base and find_sources_jar(owner_base)

    if owner_sources then
      local entry = find_entry_by_declaration(owner_sources, symbol)
      if entry then
        local path = open_in_jar(owner_sources, entry, symbol, root, member)
        if path then
          index[fqn] = { jar = owner, entry = entry, file = path }
          write_index(index)
        end
        return
      end
    end

    local stdlib = stdlib_sources_jar(jars)
    local entry = stdlib and find_entry_by_declaration(stdlib, symbol)
    if entry then
      local path = open_in_jar(stdlib, entry, symbol, root, member)
      if path then
        -- Key on the symbol: the FQN we derived for a default-imported type is
        -- not trustworthy, but the declaring entry is.
        index["kotlin-stdlib:" .. symbol] = { jar = stdlib, entry = entry, file = path }
        write_index(index)
      end
      return
    end

    notify(fqn .. " is not on the compile classpath", vim.log.levels.WARN)
    return
  end

  -- The Android SDK is not a Maven artifact but does ship sources, as plain
  -- files needing no extraction. Check before the version-number guard rejects
  -- android.jar for having no coordinates.
  local sdk_path, sdk_api = android_sdk_source(compiled, class_path)
  if sdk_path then
    open_cached(sdk_path, symbol, root, member)
    index[fqn] = { jar = compiled, entry = class_path .. ".java", file = sdk_path }
    write_index(index)
    notify(("%s.java  (%s)"):format(symbol or fqn, sdk_api))
    return
  end

  local basename = sources_basename(compiled)
  if not basename then
    -- Build-generated jars end up here: R.jar, core-lambda-stubs and friends
    -- carry no coordinates, and no repository will ever serve sources for them.
    notify(
      ("%s lives in %s, which is not a Maven artifact -- no sources to fetch"):format(
        symbol or fqn,
        vim.fn.fnamemodify(compiled, ":t")
      ),
      vim.log.levels.WARN
    )
    return
  end

  -- Resolve the real entry name rather than assuming it equals the package path.
  -- Kotlin Multiplatform sources jars prefix entries with their source set --
  -- koin ships KoinComponent.kt as `commonMain/org/koin/core/component/...` --
  -- while a plain AAR has no prefix at all. A trailing-glob match covers both
  -- without needing to know which kind of library this is.
  local function open_from(sources_jar)
    for _, ext in ipairs { ".kt", ".java" } do
      local listed = vim
        .system({
          "unzip",
          "-Z1",
          sources_jar,
          "*" .. class_path .. ext,
        }, { text = true })
        :wait()

      local entry = vim.split(vim.trim(listed.stdout or ""), "\n", { trimempty = true })[1]

      -- Path miss does not mean absent: Kotlin lets a file declare types whose
      -- names it does not share. Fall back to searching for the declaration.
      if not entry and ext == ".kt" then
        entry = find_entry_by_declaration(sources_jar, symbol)
      end

      if entry then
        local path = open_in_jar(sources_jar, entry, symbol, root, member)
        if path then
          index[fqn] = { jar = compiled, entry = entry, file = path }
          write_index(index)
        end
        return true
      end
    end
    return false
  end

  local sources_jar = find_sources_jar(basename)
  if sources_jar then
    if not open_from(sources_jar) then
      notify(
        ("%s not found inside %s"):format(class_path, basename .. "-sources.jar"),
        vim.log.levels.WARN
      )
    end
    return
  end

  fetch_sources(root, basename, function(fetched, fetch_err)
    if not fetched then
      notify(fetch_err or "sources unavailable", vim.log.levels.WARN)
      return
    end
    if not open_from(fetched) then
      notify("fetched sources jar does not contain " .. class_path, vim.log.levels.WARN)
    end
  end)
end

vim.api.nvim_create_user_command("DepSource", M.goto_dependency_source, {
  desc = "Jump into the dependency source of the symbol under the cursor",
})

vim.keymap.set("n", "<leader>gd", M.goto_dependency_source, {
  desc = "Go to dependency source (library symbols)",
})

--- Tags for exactly `word`, case-sensitively, best candidate first.
---
--- `taglist()` honours 'ignorecase' via 'tagcase', which by default makes it
--- case-insensitive. In JVM code that conflates two genuinely different things:
---
---   LocationPermissionAnalytics   the class
---   locationPermissionAnalytics   a field holding an instance of it
---
--- Both match `^LocationPermissionAnalytics$`, so `:tjump` cannot tell them apart.
--- Filtering on exact case fixes that; ordering by kind then handles the honest
--- ambiguity of one name declared in several places, preferring the type over a
--- member that merely mentions it.
local function exact_tags(word)
  local KIND_RANK = { c = 1, i = 2, g = 3, e = 4, s = 5, t = 6, m = 7, f = 8 }

  local hits = vim.tbl_filter(function(t)
    return t.name == word
  end, vim.fn.taglist("^" .. word .. "$"))

  table.sort(hits, function(a, b)
    return (KIND_RANK[a.kind] or 99) < (KIND_RANK[b.kind] or 99)
  end)

  return hits
end

--------------------------------------------------------------------------------
-- Navigation during server startup.
--
-- kotlin-language-server needs ~23s on this repo before it can answer anything:
-- JVM start, Kotlin compiler init, and a scan of every source file. None of that
-- is cacheable -- its symbol index lives in an in-memory H2 database
-- (`jdbc:h2:mem:symbolindex`), so it is rebuilt from scratch on every launch.
--
-- Nothing here depends on that. The classpath lives in kls_database.db on disk,
-- and ctags has its own tags file, so both work the moment a buffer opens. The
-- only thing missing was a keymap: `gd` is bound in an LspAttach handler, so for
-- the first ~17 seconds it did not exist and pressing it did nothing.
--
-- Binding on FileType fixes that. LspAttach fires later and overwrites this with
-- the LSP-first version, which is the desired end state -- this is purely the
-- stopgap for the window before the server is up.
--------------------------------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "kotlin", "java" },
  group = vim.api.nvim_create_augroup("dep_source_early_nav", { clear = true }),
  callback = function(ev)
    if vim.b[ev.buf].dep_source_root then
      return -- already a library-source buffer, which binds its own keys
    end

    vim.keymap.set("n", "gd", function()
      -- If a server has come up in the meantime, prefer it.
      if #vim.lsp.get_clients { bufnr = 0, method = "textDocument/definition" } > 0 then
        vim.lsp.buf.definition()
        return
      end

      -- Project symbols are in tags; library symbols are not.
      local word = vim.fn.expand("<cword>")
      local hits = word ~= "" and exact_tags(word) or {}

      if #hits > 0 then
        -- Jump directly rather than via :tjump, which would redo the lookup
        -- case-insensitively and reintroduce the wrong candidates.
        local best = hits[1]
        vim.cmd("normal! m'") -- leave a jumplist entry so <C-o> comes back
        vim.cmd.edit(vim.fn.fnameescape(best.filename))
        if not pcall(vim.cmd, best.cmd) then
          vim.fn.search("\\V" .. vim.fn.escape(word, "\\"), "cw")
        end
        if #hits > 1 then
          notify(
            ("%d declarations of %s; showing the %s"):format(#hits, word, best.kind or "first")
          )
        end
        return
      end

      M.goto_dependency_source()
    end, {
      buffer = ev.buf,
      desc = "go to definition (pre-LSP: tags, then dependency source)",
    })
  end,
  desc = "Keep gd working before the Kotlin server finishes starting",
})

return M
