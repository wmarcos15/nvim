-- lua/plugins/treesitter.lua
--
-- Text objects, swaps and moves are declared once in the tables below; the
-- same tables feed the plugin and the keymap docs.
local select = {
    ["af"] = { query = "@function.outer", desc = "Text object: around function" },
    ["if"] = { query = "@function.inner", desc = "Text object: inside function" },
    ["ac"] = { query = "@class.outer", desc = "Text object: around class" },
    ["ic"] = { query = "@class.inner", desc = "Text object: inside class" },
    ["aa"] = { query = "@parameter.outer", desc = "Text object: around argument" },
    ["ia"] = { query = "@parameter.inner", desc = "Text object: inside argument" },
    ["ai"] = { query = "@conditional.outer", desc = "Text object: around if / conditional" },
    ["ii"] = { query = "@conditional.inner", desc = "Text object: inside if / conditional" },
    ["al"] = { query = "@loop.outer", desc = "Text object: around loop" },
    ["il"] = { query = "@loop.inner", desc = "Text object: inside loop" },
}

local swap_next = {
    ["<leader>sn"] = { query = "@parameter.inner", desc = "Swap argument with the next one" },
}
local swap_previous = {
    ["<leader>sp"] = { query = "@parameter.inner", desc = "Swap argument with the previous one" },
}

local move = {
    goto_next_start = {
        ["]f"] = { query = "@function.outer", desc = "Next function start" },
        ["]c"] = { query = "@class.outer", desc = "Next class start" },
        ["]a"] = { query = "@parameter.inner", desc = "Next argument" },
    },
    goto_next_end = {
        ["]F"] = { query = "@function.outer", desc = "Next function end" },
        ["]C"] = { query = "@class.outer", desc = "Next class end" },
    },
    goto_previous_start = {
        ["[f"] = { query = "@function.outer", desc = "Previous function start" },
        ["[c"] = { query = "@class.outer", desc = "Previous class start" },
        ["[a"] = { query = "@parameter.inner", desc = "Previous argument" },
    },
    goto_previous_end = {
        ["[F"] = { query = "@function.outer", desc = "Previous function end" },
        ["[C"] = { query = "@class.outer", desc = "Previous class end" },
    },
}

local function document_all()
    local document = require("core.keymaps").document
    for lhs, v in pairs(select) do
        document({ "o", "x" }, lhs, { desc = v.desc, group = "Text objects", tags = "select delete change yank" })
    end
    for _, tbl in ipairs({ swap_next, swap_previous }) do
        for lhs, v in pairs(tbl) do
            document("n", lhs, { desc = v.desc, group = "Editing", tags = "parameter reorder" })
        end
    end
    for _, tbl in pairs(move) do
        for lhs, v in pairs(tbl) do
            document({ "n", "x", "o" }, lhs, { desc = v.desc, group = "Movement", tags = "jump method" })
        end
    end
end

return {
    {
        "nvim-treesitter/nvim-treesitter",
        -- Pinned to master: the "main" rewrite has a different API (no
        -- nvim-treesitter.configs) and needs the tree-sitter CLI installed.
        branch = "master",
        build = ":TSUpdate",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            { "nvim-treesitter/nvim-treesitter-textobjects", branch = "master" },
        },
        config = function()
            document_all()
            require("nvim-treesitter.configs").setup({
                ensure_installed = {
                    "c", "cpp", "cmake",
                    "python",
                    "java",
                    "javascript", "typescript", "tsx", "jsdoc",
                    "lua", "luadoc", "vim", "vimdoc", "query",
                    "bash", "json", "yaml", "toml",
                    "html", "css",
                    "markdown", "markdown_inline",
                },
                auto_install = true, -- install a parser the first time a new filetype is opened
                sync_install = false,

                highlight = {
                    enable = true,
                    -- Skip very large files (performance)
                    disable = function(_, buf)
                        local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
                        return ok and stats and stats.size > 500 * 1024
                    end,
                },

                indent = { enable = true },

                textobjects = {
                    select = { enable = true, lookahead = true, keymaps = select },
                    swap = { enable = true, swap_next = swap_next, swap_previous = swap_previous },
                    move = vim.tbl_extend("force", { enable = true, set_jumps = true }, move),
                },
            })
        end,
    },

    -- Auto-close brackets and quotes
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        opts = { check_ts = true }, -- use treesitter to avoid pairing inside strings / comments
    },

    -- Colour matching brackets by nesting depth
    {
        "HiPhish/rainbow-delimiters.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("rainbow-delimiters.setup").setup({
                strategy = { [""] = require("rainbow-delimiters").strategy["global"] },
                query = { [""] = "rainbow-delimiters" },
            })
        end,
    },
}
