local keymap = vim.keymap
local Terminal = require("toggleterm.terminal").Terminal

local float_term = Terminal:new({
  direction = "float",
  close_on_exit = true,
  on_open = function(term)
    vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", { silent = true, desc = "close terminal" })
  end,
})

keymap.set("n", "<leader>T", function()
  float_term:toggle()
end, { desc = "toggle floating terminal" })
