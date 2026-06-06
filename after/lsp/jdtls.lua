-- jdtls is started by after/ftplugin/java.lua via nvim-jdtls (start_or_attach),
-- which provides the full config (cmd, cmd_env, settings, workspace dir).
-- This file registers only the bare minimum for vim.lsp.enable() "jdtls"
-- to pass health checks. The actual LSP start happens in the ftplugin.

local function root_dir(bufnr, on_dir)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local root = vim.fs.root(filename, { "settings.gradle", "settings.gradle.kts", "gradlew" })
    or vim.fs.root(filename, { "build.gradle", "build.gradle.kts", "pom.xml", "build.xml", ".git" })

  if root then
    on_dir(root)
  end
end

---@type vim.lsp.Config
return {
  root_dir = root_dir,
  filetypes = { "java" },
}
