--------------------------------------------------------------------------------
-- Android resource navigation -- the res/ half of go-to-definition.
--
-- Why this exists: no language server on an AGP project can jump from
-- `R.string.foo` to the `<string name="foo">` that declares it. The reason is not
-- a missing feature, it is what AGP hands the server. `R` reaches the compile
-- classpath as `build/intermediates/compile_r_class_jar/<variant>/R.jar` -- a jar
-- of `public static int` fields with no sources jar beside it. So
-- kotlin-language-server resolves the symbol correctly (hover works, the type is
-- right) and then has nowhere to send you: textDocument/definition either comes
-- back empty or points at a decompiled temp file. `strings.xml` is never a
-- candidate, because res/ is not on any classpath.
--
-- Android Studio does not resolve this through the classpath either -- it indexes
-- res/ separately and maps R fields onto resource declarations. This does the
-- same thing with ripgrep instead of an index: one query over `res/values*/*.xml`
-- costs ~50 ms on a repo with 89k strings across 1499 files, which is well under
-- the threshold where a jump feels deferred. Nothing is pre-indexed, so nothing
-- goes stale.
--
-- Three directions are covered:
--   R.string.foo   (.kt/.java)  -> the declaration            `gd`
--   @string/foo    (.xml)       -> the declaration            `gd`
--   <string name="foo">         -> every reference to it      <leader>lu
-- plus <leader>lt to list a resource across every qualifier directory at once,
-- which is the view you want when checking translations.
--------------------------------------------------------------------------------

local M = {}

local ROOT_MARKERS = { "settings.gradle", "settings.gradle.kts", "gradlew", ".git" }

--- Resource types declared as `<tag name="...">` inside res/values*/*.xml, mapped
--- to every element that may declare one.
---
--- The mapping is not identity: `R.array.foo` is declared by any of three
--- elements, and `R.styleable.Foo` by `<declare-styleable>`. AAPT collapses them,
--- so a lookup that only tried the element of the same name would miss.
local VALUE_ELEMENTS = {
  array = { "array", "string-array", "integer-array" },
  attr = { "attr" },
  bool = { "bool" },
  color = { "color" },
  dimen = { "dimen" },
  fraction = { "fraction" },
  integer = { "integer" },
  plurals = { "plurals" },
  string = { "string" },
  style = { "style" },
  styleable = { "declare-styleable" },
  -- `<item type="id" name="foo"/>`; ids are usually declared in layouts instead,
  -- which resource_definitions() handles separately.
  id = { "item" },
}

--- Resource types stored one file per resource, under res/<type>[-qualifier]/.
--- `color` and `xml` are in both tables on purpose -- a colour is either a
--- `<color>` value or a ColorStateList file, and both are legal.
local FILE_DIRS = {
  anim = true,
  animator = true,
  color = true,
  drawable = true,
  font = true,
  interpolator = true,
  layout = true,
  menu = true,
  mipmap = true,
  navigation = true,
  raw = true,
  transition = true,
  xml = true,
}

--- Element name -> the `R.<type>` it is reachable through. Inverse of
--- VALUE_ELEMENTS, used when starting from a declaration rather than a reference.
local ELEMENT_TYPE = {}
for rtype, elements in pairs(VALUE_ELEMENTS) do
  for _, element in ipairs(elements) do
    -- `item` is ambiguous (it declares ids, but also appears inside arrays and
    -- styles), so it must not claim the slot from a specific element.
    if ELEMENT_TYPE[element] == nil or element ~= "item" then
      ELEMENT_TYPE[element] = rtype
    end
  end
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "android-res" })
end

local function project_root()
  return vim.fs.root(0, ROOT_MARKERS) or vim.fn.getcwd()
end

--- Escape the regex metacharacters ripgrep would otherwise act on.
---
--- Resource names are `[A-Za-z0-9_]` once AAPT has sanitised them, but the XML
--- side allows dots (`@style/Theme.App`), and a raw `.` would match any
--- character -- enough to make `@string/a.b` find `a_b` too.
local function escape(name)
  return (name:gsub("[%.%[%]%(%)%*%+%?%^%$%\\%|%{%}]", "\\%0"))
end

--- Run ripgrep at the project root and return its stdout lines.
---
--- Blocking on purpose: a jump has to resolve before the keymap returns so the
--- caller can tell "handled" from "not a resource" and fall through to the LSP.
--- At ~50 ms this is below the point where the wait is perceptible.
local function rg(args, root)
  local cmd = { "rg", "--color=never", "--glob", "!**/build/**" }
  vim.list_extend(cmd, args)

  local result = vim.system(cmd, { cwd = root, text = true }):wait()

  -- 1 means "no matches", which is an answer, not a failure.
  if result.code > 1 then
    notify("rg failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
    return {}
  end

  return vim.split(result.stdout or "", "\n", { trimempty = true })
end

--------------------------------------------------------------------------------
-- Recognising a resource reference under the cursor.
--------------------------------------------------------------------------------

--- Spans of `R.<type>.<name>` on `line`, as { s, e, type, name, framework }.
---
--- The package prefix is read from the text to the left rather than captured:
--- a pattern with a leading `[%w_.]*` backtracks into names that merely contain
--- an `R`, and the only thing the prefix is needed for is spotting `android.R`,
--- whose resources live in the SDK and not in this tree.
local function code_refs(line)
  local spans = {}
  local init = 1

  while true do
    local s, e, rtype, name = line:find("R%.([%a_][%w_]*)%.([%a_][%w_]*)", init)
    if not s then
      break
    end

    -- A preceding identifier char means this is `FooR.bar.baz`, not a reference.
    local prev = s > 1 and line:sub(s - 1, s - 1) or ""
    if not prev:match("[%w_]") then
      table.insert(spans, {
        s = s,
        e = e,
        type = rtype,
        name = name,
        framework = line:sub(1, s - 1):match("android%.$") ~= nil,
      })
    end

    init = e + 1
  end

  return spans
end

--- Spans of `@string/foo`, `@+id/foo`, `?attr/foo` and their package-qualified
--- forms on `line`.
---
--- The two shapes are matched separately. A single pattern with an optional
--- `<pkg>:` group backtracks catastrophically on the unqualified form --
--- `@string/foo` resolves to type `g`, name `foo` -- because `[%w_.]*` happily
--- eats `strin` and leaves `g` to satisfy the type group.
local function xml_refs(line)
  local spans = {}

  local function scan(pattern, qualified)
    local init = 1
    while true do
      local s, e, a, b, c = line:find(pattern, init)
      if not s then
        break
      end

      local pkg, rtype, name = nil, a, b
      if qualified then
        pkg, rtype, name = a, b, c
      end

      -- Skip anything already claimed by the qualified pass.
      local overlaps = false
      for _, span in ipairs(spans) do
        if s <= span.e and e >= span.s then
          overlaps = true
          break
        end
      end

      if not overlaps then
        table.insert(spans, {
          s = s,
          e = e,
          type = rtype,
          name = name,
          framework = pkg == "android",
        })
      end

      init = e + 1
    end
  end

  scan("[@?]%+?([%w_.]+):([%a_][%w_]*)/([%w_.]+)", true)
  scan("[@?]%+?([%a_][%w_]*)/([%w_.]+)", false)

  table.sort(spans, function(x, y)
    return x.s < y.s
  end)

  return spans
end

--- The resource reference under the cursor, or nil.
function M.reference_at_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.fn.col(".")

  local spans = vim.bo.filetype == "xml" and xml_refs(line) or code_refs(line)

  for _, span in ipairs(spans) do
    if col >= span.s and col <= span.e then
      return span
    end
  end

  -- With the cursor off every span, one reference on the line is unambiguous --
  -- but only if the cursor is not itself on a word. `R.string.foo,` with the
  -- cursor on the comma means the string; `HeartRateZoneType.MAX -> R.string.foo`
  -- with the cursor on the enum does not, and hijacking it there would break `gd`
  -- for every symbol that happens to share a line with a resource.
  local under = line:sub(col, col)
  if #spans == 1 and not under:match("[%w_]") then
    return spans[1]
  end

  return nil
end

--- The resource *declared* on the current line of a res/values*/ file, or nil.
local function declaration_at_cursor()
  if not vim.api.nvim_buf_get_name(0):match("/res/values[^/]*/") then
    return nil
  end

  local line = vim.api.nvim_get_current_line()
  local name = line:match('name%s*=%s*"([^"]+)"')
  if not name then
    return nil
  end

  local element = line:match("<%s*([%w_%-]+)")
  -- `<item type="id" name="foo"/>` says which type it declares; a bare `<item>`
  -- inside an array or style declares nothing addressable.
  local rtype = line:match('type%s*=%s*"([%w_]+)"') or ELEMENT_TYPE[element or ""]

  return rtype and { type = rtype, name = name } or nil
end

--- The resource a file *is*, derived from its path: res/layout/foo.xml is
--- `R.layout.foo`. The fallback when neither a reference nor a declaration is
--- under the cursor.
local function resource_of_file()
  local path = vim.api.nvim_buf_get_name(0)
  local dir, file = path:match("/res/([%w_]+)[^/]*/([^/]+)$")
  if not dir or dir == "values" or not FILE_DIRS[dir] then
    return nil
  end

  return { type = dir, name = (file:gsub("%..*$", "")) }
end

--------------------------------------------------------------------------------
-- Locating declarations.
--------------------------------------------------------------------------------

--- Rank hits so the one you meant is first: the current module before any other,
--- then the unqualified `values/` (or `drawable/`, ...) before every translation
--- and density variant, then path order for stability.
---
--- Module before qualifier matters because a resource name is not unique across a
--- 58-module repo -- `cancel` has 230 declarations here, six modules times their
--- locales -- and the one that compiles into the file you are reading is the one
--- in its own module.
---
--- Each hit is tagged with `same_module`, which is what tells a certain pick from
--- a guess: `nil` when the current buffer is not inside a module and the question
--- cannot be answered.
local function rank(hits, root)
  local current = vim.api.nvim_buf_get_name(0)
  local module = current:sub(#root + 2):match("^(.*)/src/")

  for _, hit in ipairs(hits) do
    local hit_module = hit.filename:match("^(.*)/src/")
    -- Spelt out rather than `module and (hit_module == module) or nil`: that
    -- idiom collapses a legitimate `false` to `nil`, which is the difference
    -- between "another module" and "cannot tell".
    if module then
      hit.same_module = hit_module == module
    end
    -- `values/` scores 0, `values-zh-rCN/` scores 1.
    local qualifier = hit.filename:match("/res/[%w_]+%-[^/]*/") and 1 or 0
    hit.score = (hit.same_module and 0 or 2) + qualifier
  end

  table.sort(hits, function(a, b)
    if a.score ~= b.score then
      return a.score < b.score
    end
    return a.filename < b.filename
  end)

  return hits
end

--- Every declaration of `resource`, best first. Quickfix-shaped items.
local function resource_definitions(resource, root)
  local hits = {}
  local name = escape(resource.name)

  local elements = VALUE_ELEMENTS[resource.type]
  if elements then
    local pattern = ('<(%s)[^>]*\\bname="%s"'):format(table.concat(elements, "|"), name)
    for _, line in
      ipairs(rg({
        "--no-heading",
        "--line-number",
        "--glob",
        "**/res/values*/*.xml",
        "-e",
        pattern,
      }, root))
    do
      local file, lnum, text = line:match("^([^:]+):(%d+):(.*)$")
      if file then
        table.insert(hits, {
          filename = file,
          lnum = tonumber(lnum),
          col = 1,
          text = vim.trim(text),
        })
      end
    end
  end

  -- Ids are declared where they are first used, as `@+id/foo` in a layout.
  if resource.type == "id" then
    for _, line in
      ipairs(rg({
        "--no-heading",
        "--line-number",
        "--glob",
        "**/res/**/*.xml",
        "-e",
        ("@\\+id/%s\\b"):format(name),
      }, root))
    do
      local file, lnum, text = line:match("^([^:]+):(%d+):(.*)$")
      if file then
        table.insert(
          hits,
          { filename = file, lnum = tonumber(lnum), col = 1, text = vim.trim(text) }
        )
      end
    end
  end

  if FILE_DIRS[resource.type] then
    for _, file in
      ipairs(rg({
        "--files",
        "--glob",
        ("**/res/%s*/%s.*"):format(resource.type, resource.name),
      }, root))
    do
      table.insert(hits, { filename = file, lnum = 1, col = 1, text = file })
    end
  end

  return rank(hits, root)
end

--- Every reference to `resource`, in code and in XML.
local function resource_references(resource, root)
  local name = escape(resource.name)
  local hits = {}

  local queries = {
    {
      glob = "**/*.{kt,java}",
      -- `R.styleable.Foo_bar` is how a styleable attribute is read, so the name
      -- may legitimately continue past the resource itself.
      pattern = ("\\bR\\.%s\\.%s%s"):format(
        escape(resource.type),
        name,
        resource.type == "styleable" and "" or "\\b"
      ),
    },
    {
      glob = "**/*.xml",
      pattern = ("[@?]\\+?(android:)?%s/%s\\b"):format(escape(resource.type), name),
    },
  }

  for _, query in ipairs(queries) do
    for _, line in
      ipairs(
        rg({ "--no-heading", "--line-number", "--glob", query.glob, "-e", query.pattern }, root)
      )
    do
      local file, lnum, text = line:match("^([^:]+):(%d+):(.*)$")
      if file then
        table.insert(hits, {
          filename = file,
          lnum = tonumber(lnum),
          col = 1,
          text = vim.trim(text),
        })
      end
    end
  end

  return hits
end

--------------------------------------------------------------------------------
-- Entry points.
--------------------------------------------------------------------------------

--- Absolute paths, so a jump works regardless of cwd. rg reports relative to root.
local function absolutise(hits, root)
  for _, hit in ipairs(hits) do
    hit.filename = root .. "/" .. hit.filename
  end
  return hits
end

local function jump_to(hit)
  vim.cmd("normal! m'") -- leave a jumplist entry so <C-o> comes back
  vim.cmd.edit(vim.fn.fnameescape(hit.filename))
  vim.api.nvim_win_set_cursor(0, { hit.lnum, 0 })
  vim.cmd("normal! zv")
end

--- Jump to the declaration of the resource under the cursor.
---
--- Returns false when the cursor is not on a resource reference at all, which is
--- the signal for the caller to fall through to its normal go-to-definition.
--- Returns true once this has taken responsibility -- including when the resource
--- is real but undeclared, because falling through would land in a decompiled
--- R.jar and report a "definition" that answers nothing.
---@return boolean handled
function M.goto_definition()
  local resource = M.reference_at_cursor()
  if not resource then
    return false
  end

  if resource.framework then
    notify(
      ("@android:%s/%s is a framework resource -- not in this tree"):format(
        resource.type,
        resource.name
      ),
      vim.log.levels.WARN
    )
    return true
  end

  local root = project_root()
  local hits = absolutise(resource_definitions(resource, root), root)

  if #hits == 0 then
    notify(
      ("no declaration of %s/%s in res/"):format(resource.type, resource.name),
      vim.log.levels.WARN
    )
    return true
  end

  jump_to(hits[1])

  -- Warn only when the pick was a guess. A hit inside the current module is the
  -- one that compiles, however many other modules declare the same name -- saying
  -- "229 other declarations" there is noise. A hit from *another* module means
  -- this module does not declare the resource, so which one was chosen is a real
  -- question, and the answer may be wrong.
  if hits[1].same_module == false and #hits > 1 then
    local module = hits[1].filename:sub(#root + 2):match("^(.*)/src/") or "?"
    notify(
      ("%s/%s not declared in this module -- showing %s, %d other candidate(s), <leader>lt to list"):format(
        resource.type,
        resource.name,
        module,
        #hits - 1
      ),
      vim.log.levels.WARN
    )
  end

  return true
end

--- List every declaration of the resource under the cursor -- across modules and
--- across qualifier directories -- in the location list.
---
--- This is the translation view: one line per locale, each showing the actual
--- text, so `values/` and `values-zh-rCN/` sit next to each other.
function M.list_declarations()
  local resource = M.reference_at_cursor() or declaration_at_cursor() or resource_of_file()
  if not resource then
    notify("no resource under the cursor", vim.log.levels.WARN)
    return
  end

  local root = project_root()
  local hits = absolutise(resource_definitions(resource, root), root)

  if #hits == 0 then
    notify(
      ("no declaration of %s/%s in res/"):format(resource.type, resource.name),
      vim.log.levels.WARN
    )
    return
  end

  vim.fn.setloclist(0, {}, " ", {
    title = ("%s/%s -- %d declaration(s)"):format(resource.type, resource.name, #hits),
    items = hits,
  })
  vim.cmd.lopen()
end

--- Send every reference to the resource under the cursor to the quickfix list.
---
--- Resolution order is most-specific-first: a reference under the cursor wins
--- over the declaration on the line, which wins over "this file *is* a resource"
--- -- so it works both on `@string/foo` inside a layout and on the
--- `<string name="foo">` that declares it.
function M.list_references()
  local resource = M.reference_at_cursor() or declaration_at_cursor() or resource_of_file()
  if not resource then
    notify("no resource under the cursor", vim.log.levels.WARN)
    return
  end

  local root = project_root()
  local hits = absolutise(resource_references(resource, root), root)

  if #hits == 0 then
    notify(("%s/%s is never referenced"):format(resource.type, resource.name))
    return
  end

  vim.fn.setqflist({}, " ", {
    title = ("%s/%s -- %d reference(s)"):format(resource.type, resource.name, #hits),
    items = hits,
  })
  vim.cmd.copen()
end

--------------------------------------------------------------------------------
-- Commands and keymaps.
--------------------------------------------------------------------------------

vim.api.nvim_create_user_command("ResDefinition", function()
  if not M.goto_definition() then
    notify("no resource reference under the cursor", vim.log.levels.WARN)
  end
end, { desc = "Jump to the Android resource under the cursor" })

vim.api.nvim_create_user_command("ResDeclarations", M.list_declarations, {
  desc = "List the Android resource under the cursor across all qualifiers",
})

vim.api.nvim_create_user_command("ResUsages", M.list_references, {
  desc = "List every reference to the Android resource under the cursor",
})

vim.keymap.set("n", "<leader>lt", M.list_declarations, {
  desc = "Android res: list all translations/qualifiers",
})

vim.keymap.set("n", "<leader>lu", M.list_references, {
  desc = "Android res: list all references",
})

--------------------------------------------------------------------------------
-- `gd` in XML.
--
-- Kotlin and Java get their resource-aware `gd` from lsp_conf.lua, which already
-- owns that key. XML has no server at all -- kotlin-language-server declares
-- `filetypes = { "kotlin" }` -- so LspAttach never fires there and `gd` keeps its
-- default meaning, a local-declaration search that cannot leave the buffer.
--------------------------------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
  pattern = "xml",
  group = vim.api.nvim_create_augroup("android_res_xml_nav", { clear = true }),
  callback = function(ev)
    vim.keymap.set("n", "gd", function()
      if not M.goto_definition() then
        notify("no resource reference under the cursor", vim.log.levels.WARN)
      end
    end, {
      buffer = ev.buf,
      desc = "go to Android resource definition",
    })
  end,
  desc = "Resource-aware gd in Android XML",
})

return M
