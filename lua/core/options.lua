-- lua/core/options.lua
local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Tabs & indentation
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.autoindent = true
opt.smartindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = false
opt.incsearch = true

-- Appearance
opt.termguicolors = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false

-- Splits
opt.splitbelow = true
opt.splitright = true

-- Performance
opt.updatetime = 50
opt.timeoutlen = 300

-- Undo
opt.undofile = true
opt.undodir = os.getenv("HOME") .. "/.vim/undodir"

-- Misc
opt.mouse = "a"
opt.swapfile = false
opt.backup = false
opt.encoding = "utf-8"
opt.fileencoding = "utf-8"
opt.backspace = "indent,eol,start"
