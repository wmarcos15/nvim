-- lua/plugins/editing.lua
return {
    -- ys / cs / ds: add, change, delete surrounding quotes, brackets, tags
    {
        "kylechui/nvim-surround",
        version = "*",
        event = "VeryLazy",
        opts = {},
    },

    -- <leader>u: browse the undo history as a tree (undo is persistent, see options.lua)
    {
        "mbbill/undotree",
        cmd = "UndotreeToggle",
        init = function()
            vim.g.undotree_SetFocusWhenToggle = 1
            vim.g.undotree_WindowLayout = 2
        end,
    },
}
