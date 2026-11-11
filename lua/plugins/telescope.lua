-- lua/plugins/telescope.lua
return {
    {
        "nvim-telescope/telescope.nvim",
        branch = "0.1.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-web-devicons",
            "nvim-treesitter/nvim-treesitter",
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        },
        config = function()
            local telescope = require("telescope")
            local actions = require("telescope.actions")

            telescope.setup({
                defaults = {
                    preview = {
                        treesitter = false,
                    },
                    prompt_prefix = " ",
                    selection_caret = " ",
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

                    -- Keep large C/C++ build output out of find_files and
                    -- live_grep. Lua patterns, matched against the whole path,
                    -- so the "$"-anchored ones only hit real extensions.
                    file_ignore_patterns = {
                        -- VCS / deps
                        "^%.git/", "/%.git/", "node_modules/",

                        -- Build trees
                        "^build/", "/build/",
                        "^out/", "/out/",
                        "cmake%-build.*/",
                        "CMakeFiles/",
                        "%.dSYM/",
                        "cmake_install%.cmake$",
                        "CMakeCache%.txt$",

                        -- clangd / ccls index caches (these get huge)
                        "%.cache/",
                        "%.ccls%-cache/",

                        -- Object files, archives, shared & static libs
                        "%.o$", "%.obj$", "%.lo$",
                        "%.a$", "%.lib$",
                        "%.so$", "%.so%.%d", "%.dylib$", "%.dll$",
                        "%.d$",   -- make dependency files
                        "%.gch$", "%.pch$",

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
                    find_files = {
                        hidden = true,
                    },
                    live_grep = {
                        additional_args = function()
                            return { "--hidden" }
                        end,
                    },
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

            telescope.load_extension("fzf")
        end,
    },
}
