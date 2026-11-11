-- lua/core/keymaps.lua
local opts = { noremap = true, silent = true }
local keymap = vim.api.nvim_set_keymap

-- Space as leader
keymap("n", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Modes:
--     normal       = "n"
--     insert       = "i"
--     visual       = "v"
--     visual block = "x"
--     terminal     = "t"
--     command      = "c"

-- NORMAL --

-- Window nav
keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)

-- Splits
keymap("n", "<leader>v", ":vertical split<CR>", opts)
keymap("n", "<leader>h", ":split<CR>", opts)

-- File explorer
keymap("n", "<leader>w", ":Ex<CR>", opts)

-- Save & quit
keymap("n", "<leader>s", ":w<CR>", opts)
keymap("n", "<leader>q", ":q<CR>", opts)

-- Center cursor on jumps
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- VISUAL --

-- Stay in indent mode
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- Move text up and down
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- EXTRA --

-- Yank to system clipboard
vim.keymap.set({"n", "v"}, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])

-- Paste without clobbering register
vim.keymap.set({"n", "v"}, "<leader>p", [["_dP]]) -- Best keymap ever (by ThePrimeagen)

-- C++ --

-- Switch between header and source
-- (command name under the nvim 0.11 LSP API; the old :ClangdSwitchSourceHeader
-- was provided by lspconfig's deprecated setup() path and no longer exists)
vim.keymap.set("n", "<leader>ch", ":LspClangdSwitchSourceHeader<CR>", opts)

-- Build & run
vim.keymap.set("n", "<leader>cb", ":!cmake --build build<CR>")
vim.keymap.set("n", "<leader>cr", ":!./build/main<CR>")

-- LSP diagnostics (0.11 API: goto_prev/goto_next are deprecated)
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float)
vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end)
vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end)

-- Telescope
vim.keymap.set("n", "<leader>ff", ":Telescope find_files<CR>")
vim.keymap.set("n", "<leader>fg", ":Telescope live_grep<CR>")
vim.keymap.set("n", "<leader>fb", ":Telescope buffers<CR>")
vim.keymap.set("n", "<leader>fr", ":Telescope oldfiles<CR>")

-- HARPOON --
-- Keymaps live in lua/plugins/harpoon.lua (harpoon2 API).
-- The old harpoon.mark / harpoon.ui block that used to be here was dead code:
-- those modules don't exist on the harpoon2 branch, so the pcall always failed.
