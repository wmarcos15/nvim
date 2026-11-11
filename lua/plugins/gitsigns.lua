-- lua/plugins/gitsigns.lua
-- Keymaps: lua/core/keymaps.lua (git_attach).
return {
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            signs = {
                add          = { text = "│" },
                change       = { text = "│" },
                delete       = { text = "▼" },
                topdelete    = { text = "‾" },
                changedelete = { text = "~" },
                untracked    = { text = "┆" },
            },

            -- Git blame inline at the end of the current line (<leader>tb toggles)
            current_line_blame = true,
            current_line_blame_opts = {
                delay = 500,
                virt_text_pos = "eol",
            },

            on_attach = function(bufnr)
                require("core.keymaps").git_attach(bufnr)
            end,
        },
    },
}
