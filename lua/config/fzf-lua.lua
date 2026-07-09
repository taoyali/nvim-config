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

-- Capture search root once at VimEnter so "nvim a/b/c" searches a/b/c,
-- but never changes when switching to files in subdirectories.
-- If the first buffer is a directory (netrw), use that; otherwise use getcwd().
local search_root

local function set_root()
  local p = vim.fn.expand("%:p")
  if p ~= "" and vim.fn.isdirectory(p) == 1 then
    search_root = p
  else
    search_root = vim.fn.getcwd()
  end
end

if vim.v.vim_did_enter == 1 then
  set_root()
else
  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("nvim_fzf_cwd", { clear = true }),
    once = true,
    callback = set_root,
  })
end

vim.keymap.set("n", "<leader>ff", function()
  require("fzf-lua").files({ cwd = search_root })
end, { desc = "Fuzzy find files" })
vim.keymap.set("n", "<leader>fg", function()
  require("fzf-lua").live_grep_native({ cwd = search_root })
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
