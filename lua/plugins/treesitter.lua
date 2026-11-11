-- lua/plugins/treesitter.lua
return {
    {
        "nvim-treesitter/nvim-treesitter",
        -- Pinned to master: upstream's default branch is now the "main"
        -- rewrite, which has no nvim-treesitter.configs module, so the setup
        -- below (highlight / indent / textobjects) silently did nothing.
        branch = "master",
        build = ":TSUpdate",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            -- smart text objects (master branch, to match nvim-treesitter)
            { "nvim-treesitter/nvim-treesitter-textobjects", branch = "master" },
        },
        config = function()
            local ok, treesitter = pcall(require, "nvim-treesitter.configs")
            if not ok then return end
            treesitter.setup({
                -- Languages to install (easy to add more later)
                ensure_installed = {
                    "c", "cpp",         -- C family
                    "lua", "vim",       -- Neovim config
                    "python",           -- easy to add more later
                    "bash",
                    "markdown",
                    "json", "yaml",
                    "cmake",            -- C++ build system
                },

                auto_install = true,   -- auto install when opening new filetype
                sync_install = false,

                highlight = {
                    enable = true,
                    -- Disable for very large files (performance)
                    disable = function(lang, buf)
                        local max_filesize = 100 * 1024 -- 100 KB
                        local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
                        if ok and stats and stats.size > max_filesize then
                            return true
                        end
                    end,
                },

                indent = {
                    enable = true,
                },

                -- C++ FEATURE: Smart text objects
                -- lets you select/move by function, class, argument etc.
                textobjects = {
                    select = {
                        enable = true,
                        lookahead = true, -- jump forward to next match
                        keymaps = {
                            ["af"] = "@function.outer",  -- around function
                            ["if"] = "@function.inner",  -- inside function
                            ["ac"] = "@class.outer",     -- around class
                            ["ic"] = "@class.inner",     -- inside class
                            ["aa"] = "@parameter.outer", -- around argument
                            ["ia"] = "@parameter.inner", -- inside argument
                            ["ai"] = "@conditional.outer",
                            ["ii"] = "@conditional.inner",
                            ["al"] = "@loop.outer",
                            ["il"] = "@loop.inner",
                        },
                    },

                    -- C++ FEATURE: Swap arguments/parameters
                    swap = {
                        enable = true,
                        swap_next = {
                            ["<leader>sn"] = "@parameter.inner", -- swap with next arg
                        },
                        swap_previous = {
                            ["<leader>sp"] = "@parameter.inner", -- swap with prev arg
                        },
                    },

                    -- C++ FEATURE: Navigate between functions/classes
                    move = {
                        enable = true,
                        set_jumps = true,
                        goto_next_start = {
                            ["]f"] = "@function.outer",  -- next function
                            ["]c"] = "@class.outer",     -- next class
                            ["]a"] = "@parameter.inner", -- next argument
                        },
                        goto_next_end = {
                            ["]F"] = "@function.outer",
                            ["]C"] = "@class.outer",
                        },
                        goto_previous_start = {
                            ["[f"] = "@function.outer",  -- prev function
                            ["[c"] = "@class.outer",     -- prev class
                            ["[a"] = "@parameter.inner", -- prev argument
                        },
                        goto_previous_end = {
                            ["[F"] = "@function.outer",
                            ["[C"] = "@class.outer",
                        },
                    },
                },
            })
        end,
    },

    -- C++ FEATURE: Auto close & rename HTML/JSX tags (useful if you ever do web)
    -- and more importantly: auto pairs for <> templates in C++
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = function()
            require("nvim-autopairs").setup({
                check_ts = true, -- use treesitter to check pairs
                ts_config = {
                    cpp = { "string", "comment" }, -- don't pair inside strings/comments
                },
            })
        end,
    },

    -- C++ FEATURE: Rainbow delimiters — color matching brackets/braces
    -- insanely useful for nested templates like vector<map<string, vector<int>>>
    {
        "HiPhish/rainbow-delimiters.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("rainbow-delimiters.setup").setup({
                strategy = {
                    [""] = require("rainbow-delimiters").strategy["global"],
                },
                query = {
                    [""] = "rainbow-delimiters",
                    cpp  = "rainbow-delimiters",
                },
            })
        end,
    },
}
