-- lua/plugins/harpoon.lua
return {
    {
        "ThePrimeagen/harpoon",
        branch = "harpoon2",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            local harpoon = require("harpoon")
            harpoon:setup({
                settings = {
                    save_on_toggle = true,   -- save list when toggling menu
                    sync_on_ui_close = true, -- sync when closing UI
                },
            })

            -- =============================================
            -- Keymaps
            -- =============================================

            -- Add file to harpoon
            vim.keymap.set("n", "<leader>a", function()
                harpoon:list():add()
            end, { desc = "Harpoon add file" })

            -- Toggle quick menu
            -- Kept: <C-e> only costs the built-in scroll-down-one-line, and
            -- it's harpoon's own documented key.
            vim.keymap.set("n", "<C-e>", function()
                harpoon.ui:toggle_quick_menu(harpoon:list())
            end, { desc = "Harpoon menu" })

            -- Navigate to file 1-4
            -- Moved off <C-u>/<C-i>/<C-o>/<C-p>: those were shadowing
            -- half-page-up and the jumplist (<C-o>/<C-i>), which you need
            -- constantly after gd on a large codebase.
            for i = 1, 4 do
                vim.keymap.set("n", "<leader>" .. i, function()
                    harpoon:list():select(i)
                end, { desc = "Harpoon file " .. i })
            end

            -- Cycle through harpoon list
            -- (<C-S-P>/<C-S-N> never fired: terminals send those as plain
            -- <C-p>/<C-n> unless CSI-u encoding is on.)
            vim.keymap.set("n", "<leader>mn", function() harpoon:list():next() end,
                { desc = "Harpoon next file" })
            vim.keymap.set("n", "<leader>mp", function() harpoon:list():prev() end,
                { desc = "Harpoon previous file" })

            -- Telescope integration: browse harpoon list with fuzzy search
            local ok, telescope = pcall(require, "telescope")
            if ok then
                local conf = require("telescope.config").values
                local function toggle_telescope(harpoon_files)
                    local file_paths = {}
                    for _, item in ipairs(harpoon_files.items) do
                        table.insert(file_paths, item.value)
                    end
                    require("telescope.pickers").new({}, {
                        prompt_title = "Harpoon",
                        finder = require("telescope.finders").new_table({ results = file_paths }),
                        previewer = conf.file_previewer({}),
                        sorter = conf.generic_sorter({}),
                    }):find()
                end

                -- Joins the <leader>f* find family; <C-h> is window-left again.
                vim.keymap.set("n", "<leader>fh", function()
                    toggle_telescope(harpoon:list())
                end, { desc = "Find harpoon marks" })
            end
        end,
    },
}
