-- lua/plugins/telescope.lua
-- Launch keys (<leader>f*, gd, grr, ...) live in lua/core/keymaps.lua.
return {
    {
        "nvim-telescope/telescope.nvim",
        branch = "0.1.x",
        lazy = true, -- loads on first use (any <leader>f key or :Telescope)
        cmd = "Telescope",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-web-devicons",
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        },
        config = function()
            local telescope = require("telescope")
            local actions = require("telescope.actions")
            local document = require("core.keymaps").document

            telescope.setup({
                defaults = {
                    prompt_prefix = "\u{f002}  ",
                    selection_caret = "\u{f054} ",
                    path_display = { "truncate" },
                    sorting_strategy = "ascending",
                    layout_config = {
                        horizontal = {
                            prompt_position = "top",
                            preview_width = 0.55,
                        },
                        width = 0.87,
                        height = 0.80,
                    },

                    -- Keep build output and dependencies out of find_files and
                    -- live_grep. Lua patterns, matched against the whole path.
                    file_ignore_patterns = {
                        -- VCS / deps
                        "^%.git/", "/%.git/", "node_modules/",
                        "__pycache__/", "%.venv/", "^venv/",

                        -- Build trees
                        "^build/", "/build/",
                        "^out/", "/out/",
                        "^target/", "/target/",
                        "^dist/", "/dist/",
                        "cmake%-build.*/",
                        "CMakeFiles/",
                        "%.dSYM/",
                        "cmake_install%.cmake$",
                        "CMakeCache%.txt$",

                        -- clangd / ccls index caches (these get huge)
                        "%.cache/",
                        "%.ccls%-cache/",

                        -- Object files, archives, libraries, bytecode
                        "%.o$", "%.obj$", "%.lo$",
                        "%.a$", "%.lib$",
                        "%.so$", "%.so%.%d", "%.dylib$", "%.dll$",
                        "%.d$",
                        "%.gch$", "%.pch$",
                        "%.class$", "%.jar$", "%.pyc$",

                        -- Binaries / misc build artifacts
                        "%.out$", "%.bin$", "%.elf$", "%.exe$",
                        "%.gcda$", "%.gcno$", "%.profraw$",
                    },

                    mappings = {
                        i = {
                            ["<C-k>"] = actions.move_selection_previous,
                            ["<C-j>"] = actions.move_selection_next,
                            ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
                            ["<esc>"] = actions.close,
                        },
                        n = {
                            ["q"] = actions.close,
                        },
                    },
                },

                pickers = {
                    find_files = { hidden = true },
                    live_grep = {
                        additional_args = function() return { "--hidden" } end,
                    },
                    -- One match: jump straight there. Several: pick from a list.
                    lsp_definitions = { show_line = false },
                    lsp_references = { show_line = false, include_declaration = false },
                    lsp_implementations = { show_line = false },
                    lsp_type_definitions = { show_line = false },
                },

                extensions = {
                    fzf = {
                        fuzzy = true,
                        override_generic_sorter = true,
                        override_file_sorter = true,
                        case_mode = "smart_case",
                    },
                },
            })

            pcall(telescope.load_extension, "fzf")

            -- Docs entries for the keys that work inside a picker
            local inside = { group = "Find", where = "inside a Telescope picker" }
            local function doc(lhs, desc)
                document("i", lhs, vim.tbl_extend("force", inside, { desc = desc }))
            end
            doc("<C-j>", "Next result")
            doc("<C-k>", "Previous result")
            doc("<CR>", "Open selected result")
            doc("<C-x>", "Open result in a horizontal split")
            doc("<C-v>", "Open result in a vertical split")
            doc("<C-t>", "Open result in a new tab")
            doc("<Tab>", "Mark result (multi-select)")
            doc("<C-q>", "Send marked results to the quickfix list")
            doc("<C-u>", "Scroll preview up")
            doc("<C-d>", "Scroll preview down")
            doc("<Esc>", "Close picker")
        end,
    },
}
