require("lazy").setup({
	-- "nvim-lua/popup.nvim", -- An implementation of the Popup API from vim in Neovim
	-- "nvim-lua/plenary.nvim", -- Useful lua functions used ny lots of plugins

	-- colorschemes
	{
		"folke/tokyonight.nvim",
		lazy = false,
		priority = 1000,
		opts = {},
	},
	-- "https://github.com/aktersnurra/no-clown-fiesta.nvim.git",
	-- use ({ 'projekt0n/github-nvim-theme' })
	-- use { 'dasupradyumna/midnight.nvim' }
	-- use {'nyoom-engineering/oxocarbon.nvim'}
	-- use "EdenEast/nightfox.nvim"
	-- use { "catppuccin/nvim", as = "catppuccin" }
	-- use {"rose-pine/neovim", as = "rose-pine"}

	-- cmp for autocompletion
	{
		"hrsh7th/nvim-cmp",
		dependencies = {
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
			"hrsh7th/cmp-cmdline",
			"saadparwaiz1/cmp_luasnip",
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-nvim-lua",
			"L3MON4D3/LuaSnip",
			"rafamadriz/friendly-snippets",
		},
		config = function()
			require("wmarcos.plugins.config.cmp")
		end,
	},

	-- snippets
	"L3MON4D3/LuaSnip", --snippet engine,
	"rafamadriz/friendly-snippets", -- a bunch of snippets to use,

	-- LSP
	{
		"neovim/nvim-lspconfig",
		lazy = true,
	},

	{
		"williamboman/mason.nvim",
		config = true,
	},

	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = {
			"williamboman/mason.nvim",
			"neovim/nvim-lspconfig",
		},
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = { "clangd" },
			})
			require("wmarcos.config.lsp")  -- <- External config here
		end,
	},

	{
		"theprimeagen/harpoon",
		config = function()
			require("wmarcos.plugins.config.harpoon")
		end,
	},

	{
		"nvim-telescope/telescope.nvim",
		tag = "0.1.4",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			require("wmarcos.plugins.config.telescope")
		end,
	},

	{
		"nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
		config = function()
			require("wmarcos.plugins.config.treesitter")
		end,
	},

	{
		"kylechui/nvim-surround",
		version = "^3.0.0", -- Use for stability; omit to use `main` branch for the latest features
		event = "VeryLazy",
		config = function()
			require("nvim-surround").setup({
				-- Configuration here, or leave empty to use defaults
			})
		end
	},

	{
		"folke/trouble.nvim",
		opts = {}, -- for default options, refer to the configuration section for custom setup.
		cmd = "Trouble",
		keys = {
			{
				"<leader>xx",
				"<cmd>Trouble diagnostics toggle<cr>",
				desc = "Diagnostics (Trouble)",
			},
			{
				"<leader>xX",
				"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
				desc = "Buffer Diagnostics (Trouble)",
			},
			{
				"<leader>cs",
				"<cmd>Trouble symbols toggle focus=false<cr>",
				desc = "Symbols (Trouble)",
			},
			{
				"<leader>cl",
				"<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
				desc = "LSP Definitions / references / ... (Trouble)",
			},
			{
				"<leader>xL",
				"<cmd>Trouble loclist toggle<cr>",
				desc = "Location List (Trouble)",
			},
			{
				"<leader>xQ",
				"<cmd>Trouble qflist toggle<cr>",
				desc = "Quickfix List (Trouble)",
			},
		},
		config = function()
			require("wmarcos.trouble")
		end,
	},

	{
		"rmagatti/goto-preview",
		dependencies = { "rmagatti/logger.nvim" },
		event = "BufEnter",
		config = function()
			require("wmarcos.plugins.config.goto-preview")
		end,
	},

	"terrortylor/nvim-comment",

	{
		'nvim-lualine/lualine.nvim',
		dependencies = { 'nvim-tree/nvim-web-devicons' },
		config = function()
			require("wmarcos.plugins.config.lualine")
		end,
	},
})
