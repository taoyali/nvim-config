-- lazygit.nvim: opens lazygit in a floating window inside Neovim.
-- Installed separately via: brew install lazygit

local ok, lazygit = pcall(require, "lazygit")
if not ok then
  return
end

vim.g.lazygit_floating_window_winblend = 0
vim.g.lazygit_floating_window_scaling_factor = 0.9
vim.g.lazygit_floating_window_use_plenary = true
vim.g.lazygit_use_neovim_remote = 1

vim.g.lazygit_on_exit_callback = function()
  if pcall(require, "gitsigns") then
    require("gitsigns").refresh()
  end
  pcall(vim.cmd, "checktime")
end
