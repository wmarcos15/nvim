-- lua/plugins/gitsigns.lua
return {
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("gitsigns").setup({
                signs = {
                    add          = { text = "│" },
                    change       = { text = "│" },
                    delete       = { text = "▼" },
                    topdelete    = { text = "‾" },
                    changedelete = { text = "~" },
                    untracked    = { text = "┆" },
                },

                -- Show git blame inline at end of line
                current_line_blame = true,
                current_line_blame_opts = {
                    delay = 500,
                    virt_text_pos = "eol",
                },

                on_attach = function(bufnr)
                    local gs = package.loaded.gitsigns
                    local opts = { buffer = bufnr }

                    -- Navigation
                    vim.keymap.set("n", "]h", gs.next_hunk,  opts) -- next change
                    vim.keymap.set("n", "[h", gs.prev_hunk,  opts) -- prev change

                    -- Actions
                    vim.keymap.set("n", "<leader>hs", gs.stage_hunk,   opts) -- stage hunk
                    vim.keymap.set("n", "<leader>hr", gs.reset_hunk,   opts) -- reset hunk
                    vim.keymap.set("n", "<leader>hp", gs.preview_hunk, opts) -- preview hunk
                    vim.keymap.set("n", "<leader>hb", gs.blame_line,   opts) -- full blame popup
                    vim.keymap.set("n", "<leader>hd", gs.diffthis,     opts) -- diff current file
                    vim.keymap.set("n", "<leader>tb", gs.toggle_current_line_blame, opts)
                    vim.keymap.set("n", "<leader>td", gs.toggle_deleted, opts)

                    -- Visual mode: stage/reset selected lines only
                    vim.keymap.set("v", "<leader>hs", function()
                        gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
                    end, opts)
                    vim.keymap.set("v", "<leader>hr", function()
                        gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
                    end, opts)
                end,
            })
        end,
    },
}
