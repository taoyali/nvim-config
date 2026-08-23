--------------------------------------------------------------------------------
-- kotlin-language-server -- the Kotlin/Android server for this config.
--
-- Chosen by measurement, not reputation. It is the older, less capable server on
-- paper, but the only one of the three candidates that resolves symbols in an
-- Android Gradle Plugin project. All three were probed on identical positions in
-- the same file of a real AGP repo:
--
--                          project class   AAR class   android.jar   own decl
--   jdtls                       -              -            -           -      (empty .classpath)
--   kotlin-lsp (JetBrains)     nil            nil          nil          ok
--   kotlin-language-server      ok             ok           ok          nil
--
-- Root cause of the two failures is the same: AGP does not expose source roots
-- or the compile classpath through any standard Gradle project model. jdtls asks
-- Eclipse Buildship for an `EclipseProject` (AGP does not implement it) and gets
-- a .classpath with zero source folders. kotlin-lsp bundles no intellij.android.*
-- plugins, so its generic IntelliJ importer reports "Package directive does not
-- match the file location" for a file sitting at its correct package path.
--
-- This server sidesteps the problem: it injects an init script and asks Gradle
-- for the classpath directly. The result is cached in `kls_database.db` at the
-- project root -- 746 entries here, including android.jar, the AGP variant's R
-- class jar and jetified AARs. That file is intentionally left on disk; deleting
-- it costs a multi-minute Gradle re-resolve on next start.
--
-- Java is not served here (`filetypes` is Kotlin only) -- see tags_conf.lua.
--------------------------------------------------------------------------------

local function root_dir(bufnr, on_dir)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  -- Settings files first: on a multi-module build every module has its own
  -- build.gradle, and rooting at one would resolve a classpath for that module
  -- alone.
  local root = vim.fs.root(filename, { "settings.gradle", "settings.gradle.kts", "gradlew" })
    or vim.fs.root(filename, { "build.gradle", "build.gradle.kts", ".git" })

  if root then
    on_dir(root)
  end
end

---@type vim.lsp.Config
return {
  filetypes = { "kotlin" },
  root_dir = root_dir,
  -- Everything below goes through workspace/didChangeConfiguration, which the
  -- server reads from the `kotlin` key -- verified against
  -- KotlinWorkspaceService: JsonObject.get("kotlin"). Nothing here belongs in
  -- init_options; the server ignores it there.
  settings = {
    kotlin = {
      -- Matches this project's output: every class file under app/build carries
      -- major version 61.
      compiler = {
        jvm = { target = "17" },
      },
      externalSources = {
        -- Must stay false. When true, a jump into a dependency returns a
        -- `kls:file://...` URI, and Neovim has no handler for that scheme, so the
        -- jump simply fails. False makes the server materialise a real temp file
        -- instead -- the name is ugly (android.jar's Log arrives as
        -- Log7859816817878578483.java) but it opens.
        useKlsScheme = false,
        -- Read Java dependencies as Java. Decompiling them into approximate
        -- Kotlin costs time and loses fidelity.
        autoConvertToKotlin = false,
      },
      -- The first Gradle classpath resolve on this repo takes minutes. Diagnostics
      -- recomputed on every keystroke during that window are both wrong and
      -- expensive, so debounce well above the 250 ms default.
      diagnostics = {
        enabled = true,
        debounceTime = 1000,
      },
      -- Required for workspace symbol search across the 1000+ Kotlin files here.
      indexing = {
        enabled = true,
      },
    },
  },
}
