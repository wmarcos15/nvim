-- lua/plugins/ui.lua
--
-- Colorscheme plugins and the statusline. Which theme is active, and how each
-- one is configured, is decided in lua/core/themes.lua (the theme slots).
-- Theme plugins are `lazy = true`: only the one in use gets loaded.
return {
    { "rebelot/kanagawa.nvim", lazy = true },
    { "scottmckendry/cyberdream.nvim", lazy = true },

    -- Statusline (shape and colours follow the active theme slot)
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function() require("core.themes").statusline() end,
    },
}
