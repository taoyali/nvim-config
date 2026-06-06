local function root_dir(bufnr, on_dir)
  local filename = vim.api.nvim_buf_get_name(bufnr)
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
}
