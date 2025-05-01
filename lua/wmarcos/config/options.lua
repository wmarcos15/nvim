local options = {
	wrap = false,
	mouse = "a",
	smartindent = true,
	splitbelow = true,
	splitright = true,
	shiftwidth = 4,
	tabstop = 4,
	cursorline = false,
	number = true,
	relativenumber = true,
	termguicolors = true,
	hlsearch = false,
	incsearch = true,
}

for key, value in pairs(options) do
	vim.opt[key] = value
end

vim.cmd [[set iskeyword+=-]]
