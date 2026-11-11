-- lua/plugins/harpoon.lua
-- Keymaps: lua/core/keymaps.lua (Harpoon section).
return {
    {
        "ThePrimeagen/harpoon",
        branch = "harpoon2",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            require("harpoon"):setup({
                settings = {
                    save_on_toggle = true,   -- save list when toggling menu
                    sync_on_ui_close = true, -- sync when closing UI
                },
            })
        end,
    },
}
