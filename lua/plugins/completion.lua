-- lua/plugins/completion.lua
return {
    {
        "hrsh7th/nvim-cmp",
        -- CmdlineEnter too: otherwise ":" and "/" completion only starts
        -- working after the first time you enter insert mode.
        event = { "InsertEnter", "CmdlineEnter" },
        dependencies = {
            -- Sources
            "hrsh7th/cmp-nvim-lsp",       -- LSP completions
            "hrsh7th/cmp-buffer",          -- buffer word completions
            "hrsh7th/cmp-path",            -- filesystem path completions
            "hrsh7th/cmp-cmdline",         -- command line completions

            -- Snippets
            "L3MON4D3/LuaSnip",            -- snippet engine
            "saadparwaiz1/cmp_luasnip",    -- snippet completions
            "rafamadriz/friendly-snippets", -- snippets for most languages

            -- UI
            "onsails/lspkind.nvim",        -- VSCode-like icons in completion menu
        },
        config = function()
            local cmp = require("cmp")
            local luasnip = require("luasnip")
            local lspkind = require("lspkind")

            -- Load friendly-snippets
            require("luasnip.loaders.from_vscode").lazy_load()

            cmp.setup({
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },

                window = {
                    completion    = cmp.config.window.bordered(),
                    documentation = cmp.config.window.bordered(),
                },

                mapping = cmp.mapping.preset.insert({
                    ["<C-k>"]     = cmp.mapping.select_prev_item(),
                    ["<C-j>"]     = cmp.mapping.select_next_item(),
                    ["<C-b>"]     = cmp.mapping.scroll_docs(-4),
                    ["<C-f>"]     = cmp.mapping.scroll_docs(4),
                    ["<C-Space>"] = cmp.mapping.complete(),       -- trigger completion manually
                    ["<C-e>"]     = cmp.mapping.abort(),          -- close completion
                    ["<CR>"]      = cmp.mapping.confirm({ select = false }), -- confirm only if explicitly selected

                    -- Super-tab: next item, or jump to the next snippet placeholder
                    ["<Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                        elseif luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()  -- jump between snippet placeholders
                        else
                            fallback()
                        end
                    end, { "i", "s" }),

                    ["<S-Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                }),

                -- Completion sources in priority order
                sources = cmp.config.sources({
                    { name = "nvim_lsp", priority = 1000 }, -- LSP first
                    { name = "luasnip",  priority = 750  }, -- then snippets
                    { name = "buffer",   priority = 500  }, -- then buffer words
                    { name = "path",     priority = 250  }, -- then paths
                }),

                -- VSCode-like icons with type info
                formatting = {
                    format = lspkind.cmp_format({
                        mode = "symbol_text",
                        maxwidth = 50,
                        ellipsis_char = "...",
                        show_labelDetails = true,
                        before = function(entry, vim_item)
                            if entry.source.name == "nvim_lsp" then
                                vim_item.menu = "[LSP]"
                            elseif entry.source.name == "luasnip" then
                                vim_item.menu = "[Snip]"
                            elseif entry.source.name == "buffer" then
                                vim_item.menu = "[Buf]"
                            elseif entry.source.name == "path" then
                                vim_item.menu = "[Path]"
                            end
                            return vim_item
                        end,
                    }),
                },

                -- Don't show completion in comments
                enabled = function()
                    local context = require("cmp.config.context")
                    if vim.api.nvim_get_mode().mode == "c" then
                        return true
                    else
                        return not context.in_treesitter_capture("comment")
                            and not context.in_syntax_group("Comment")
                    end
                end,
            })

            -- Cmdline completion for "/"
            cmp.setup.cmdline("/", {
                mapping = cmp.mapping.preset.cmdline(),
                sources = { { name = "buffer" } },
            })

            -- Cmdline completion for ":"
            cmp.setup.cmdline(":", {
                mapping = cmp.mapping.preset.cmdline(),
                sources = cmp.config.sources(
                    { { name = "path" } },
                    { { name = "cmdline" } }
                ),
            })

            -- Docs entries for the completion menu keys
            local document = require("core.keymaps").document
            local function doc(lhs, desc, modes)
                document(modes or "i", lhs, { desc = desc, group = "Completion", where = "while the completion menu is open" })
            end
            doc("<C-j>", "Next completion item")
            doc("<C-k>", "Previous completion item")
            doc("<Tab>", "Next item, or jump to next snippet placeholder", { "i", "s" })
            doc("<S-Tab>", "Previous item, or jump to previous snippet placeholder", { "i", "s" })
            doc("<CR>", "Accept the selected item")
            doc("<C-Space>", "Open the completion menu")
            doc("<C-e>", "Close the completion menu")
            doc("<C-f>", "Scroll the documentation popup down")
            doc("<C-b>", "Scroll the documentation popup up")

            -- Hook cmp into autopairs (so <CR> works correctly with pairs)
            local cmp_autopairs = require("nvim-autopairs.completion.cmp")
            cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done)
        end,
    },
}
