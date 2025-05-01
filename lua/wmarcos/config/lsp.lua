local mason = require("mason")
local mason_lspconfig = require("mason-lspconfig")
local lspconfig = require("lspconfig")
local handlers = require("wmarcos.config.lsp.handlers")

mason.setup()
mason_lspconfig.setup()

mason_lspconfig.setup_handlers({
	function(server_name)
		lspconfig[server_name].setup({
			on_attach = handlers.on_attach,
			capabilities = handlers.capabilities,
		})
	end,
})

