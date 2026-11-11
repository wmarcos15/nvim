-- lua/plugins/ui.lua
return {
    {
        "rebelot/kanagawa.nvim",
        lazy = false,
        priority = 1000, -- load before everything else
        config = function()
            require("kanagawa").setup({
                compile = false,
                undercurl = true,
                transparent = true,        -- iTerm bg shows through
                terminalColors = true,
                dimInactive = false,
                theme = "wave",            -- wave = darkest, dragon, lotus
                background = {
                    dark = "wave",
                    light = "lotus",
                },
                colors = {
                    theme = {
                        all = {
                            ui = {
                                bg_gutter = "none", -- removes gutter bg
                            }
                        }
                    }
                },
                overrides = function(colors)
                    local theme = colors.theme
                    return {
                        -- Floating windows also transparent
                        NormalFloat     = { bg = "none" },
                        FloatBorder     = { bg = "none" },
                        FloatTitle      = { bg = "none" },

                        -- Telescope transparent
                        TelescopeNormal          = { bg = "none" },
                        TelescopeBorder          = { bg = "none" },
                        TelescopeResultsNormal   = { bg = "none" },
                        TelescopePreviewNormal   = { bg = "none" },
                        TelescopePromptNormal    = { bg = "none" },

                        -- Pmenu (completion menu) transparent
                        Pmenu    = { fg = theme.ui.shade0, bg = "none" },
                        PmenuSel = { bg = theme.ui.bg_p2 },

                        -- Blue/purple accent on selection & visual
                        Visual = { bg = theme.ui.bg_p2 },
                    }
                end,
            })

            vim.cmd("colorscheme kanagawa")
        end,
    },

    -- Statusline
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("lualine").setup({
                options = {
                    theme = "kanagawa",
                    globalstatus = true,
                    component_separators = "|",
                    section_separators = { left = "", right = "" },
                },
                sections = {
                    lualine_a = { "mode" },
                    lualine_b = { "branch", "diff", "diagnostics" },
                    lualine_c = { { "filename", path = 1 } },
                    lualine_x = { "encoding", "filetype" },
                    lualine_y = { "progress" },
                    lualine_z = { "location" },
                },
            })
        end,
    },
}
