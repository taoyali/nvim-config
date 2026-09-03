local keymap = vim.keymap
local hop = require("hop")
hop.setup {
  case_insensitive = true,
  char2_fallback_key = "<CR>",
  quit_key = "<Esc>",
  match_mappings = { "zh_sc" },
}

-- Keep Vim's native `f{char}` motion available.  Hop uses a leader mapping so
-- it does not intercept the single-key motion in normal, visual, or operator
-- pending mode.
keymap.set({ "n", "v", "o" }, "<leader>j", "", {
  silent = true,
  noremap = true,
  callback = function()
    hop.hint_char2()
  end,
  desc = "Hop: jump to character pair",
})

vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = function()
    vim.cmd([[
      hi HopNextKey cterm=bold ctermfg=176 gui=bold guibg=#ff00ff guifg=#ffffff
      hi HopNextKey1 cterm=bold ctermfg=176 gui=bold guibg=#ff00ff guifg=#ffffff
      hi HopNextKey2 cterm=bold ctermfg=176 gui=bold guibg=#ff00ff guifg=#ffffff
    ]])
  end,
})
