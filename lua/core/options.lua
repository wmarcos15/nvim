-- lua/core/options.lua
local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Tabs & indentation
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true
opt.breakindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = false
opt.incsearch = true
opt.inccommand = "split" -- live preview of :s/old/new/

-- Appearance
opt.termguicolors = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false
opt.showmode = false -- the statusline already shows the mode
opt.list = true      -- make stray whitespace visible
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Splits
opt.splitbelow = true
opt.splitright = true

-- Timing
opt.updatetime = 50
opt.timeoutlen = 300

-- Undo (persistent; browse it with <leader>u)
opt.undofile = true
opt.undodir = vim.fn.expand("~/.vim/undodir")

-- Misc
opt.mouse = "a"
opt.swapfile = false
opt.backup = false
opt.confirm = true -- ask instead of failing on :q with unsaved changes
opt.isfname:append("@-@")
