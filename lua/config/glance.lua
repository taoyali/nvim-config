local glance = require("glance")

glance.setup {
  height = 25,
  border = {
    enable = true,
  },
}

vim.keymap.set("n", "<leader>lgd", "<cmd>Glance definitions<cr>", { desc = "Glance definitions" })
vim.keymap.set("n", "<leader>lgr", "<cmd>Glance references<cr>", { desc = "Glance references" })
vim.keymap.set("n", "<leader>lgi", "<cmd>Glance implementations<cr>", { desc = "Glance implementations" })
