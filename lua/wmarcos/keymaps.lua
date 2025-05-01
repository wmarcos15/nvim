local opts = {noremap = true, silent = true}
local term_opts = {silent = true}

local keymap = vim.api.nvim_set_keymap -- shorten for readability

-- Space as leader
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Modes:
--     normal = "n"
--     insert = "i"
--     visual = "v"
--     visual block = "x"
--     terminal = "t"
--     command = "c"

-- NORMAL
-- Colorscheme
-- keymap("n", "<leader>0, "so ~.config/nvim/lua/wmarcos/colorscheme.lua<cr>", opts)
-- Useful when trying new colorschemes

-- Window nav
keymap("n", "<C-h>", "<C-w>h", opts) 
keymap("n", "<C-j>", "<C-w>j", opts) 
keymap("n", "<C-k>", "<C-w>k", opts) 
keymap("n", "<C-l>", "<C-w>l", opts) 

keymap("n", "<leader>v", ":vertical split<cr>", opts)
keymap("n", "<leader>h", ":split<cr>", opts)

keymap("n", "<leader>w", ":Ex<cr>", opts) -- Show the project files

-- Visual --
-- Stay in indent mode
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- Move text up and down
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Extra --
vim.keymap.set({"n", "v"}, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])

vim.keymap.set({"n", "v"}, "<leader>p", [["_dP"]]) -- Best keymap ever (by ThePrimeagean)
