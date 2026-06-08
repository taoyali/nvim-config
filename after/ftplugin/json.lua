vim.keymap.set({ "n", "v" }, "<leader>cf", ":JSONFormat<cr>", {
  buffer = true,
  silent = true,
  desc = "format JSON buffer",
})
