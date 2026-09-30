-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "sh", "<C-w>h", { desc = "Move to left window" })
vim.keymap.set("n", "sj", "<C-w>j", { desc = "Move to lower window" })
vim.keymap.set("n", "sk", "<C-w>k", { desc = "Move to upper window" })
vim.keymap.set("n", "sl", "<C-w>l", { desc = "Move to right window" })
