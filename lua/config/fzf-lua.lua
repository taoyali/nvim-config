-- Compute cwd from current buffer at runtime (not at init time).
-- This way "nvim ../project" searches in ../project, not the terminal's cwd.
local function buf_cwd()
  local p = vim.fn.expand("%:p")
  if p == "" then return vim.fn.getcwd() end                    -- unnamed buffer
  if vim.fn.isdirectory(p) == 1 then return p end               -- netrw directory
  return vim.fn.fnamemodify(p, ":h")                             -- file's directory
end

require("fzf-lua").setup {
  defaults = {
    file_icons = "mini",
  },
  winopts = {
    row = 0.5,
    height = 0.7,
  },
  files = {
    previewer = false,
    git_icons = true,
    -- using .gitignore is usually good, but still we may want to include some files,
    -- you can create a file `.rgignore` to "unignore" those files, e.g., `.env` files.
    -- see also https://github.com/BurntSushi/ripgrep/discussions/2512
    -- and https://www.reddit.com/r/linuxquestions/comments/zycvud/ripgrep_respect_gitignore_but_show_env_files/
    no_ignore = false,
  },
  grep = {
    RIPGREP_CONFIG_PATH = vim.env.RIPGREP_CONFIG_PATH,
  },
}

-- Must be Lua functions (not <cmd> mappings) so buf_cwd() is evaluated
-- at each invocation, not frozen at init time.
vim.keymap.set("n", "<leader>ff", function()
  require("fzf-lua").files({ cwd = buf_cwd() })
end, { desc = "Fuzzy find files" })
vim.keymap.set("n", "<leader>fg", function()
  require("fzf-lua").live_grep_native({ cwd = buf_cwd() })
end, { desc = "Fuzzy grep files" })
vim.keymap.set(
  "n",
  "<leader>fh",
  "<cmd>FzfLua helptags<cr>",
  { desc = "Fuzzy grep tags in help files" }
)
vim.keymap.set(
  "n",
  "<leader>ft",
  "<cmd>FzfLua lsp_document_symbols<cr>",
  { desc = "Fuzzy search buffer tags" }
)
vim.keymap.set(
  "n",
  "<leader>fb",
  "<cmd>FzfLua buffers<cr>",
  { desc = "Fuzzy search opened buffers" }
)
vim.keymap.set(
  "n",
  "<leader>fr",
  "<cmd>FzfLua oldfiles<cr>",
  { desc = "Fuzzy search opened files history" }
)
