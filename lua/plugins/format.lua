-- lua/plugins/format.lua
--
-- Formatting. <leader>cf formats the file (or the visual selection).
-- Format-on-save is off by default; <leader>tf toggles it for the session,
-- or set vim.g.format_on_save = true below to make it permanent.
--
-- Languages without an entry (Java, Lua, ...) fall back to their language
-- server's formatter.
vim.g.format_on_save = false

return {
    {
        "stevearc/conform.nvim",
        event = "BufWritePre",
        cmd = "ConformInfo",
        opts = {
            formatters_by_ft = {
                c = { "clang-format" },
                cpp = { "clang-format" },
                python = { "ruff_organize_imports", "ruff_format" },
                javascript = { "prettier" },
                javascriptreact = { "prettier" },
                typescript = { "prettier" },
                typescriptreact = { "prettier" },
                json = { "prettier" },
                jsonc = { "prettier" },
                css = { "prettier" },
                html = { "prettier" },
                yaml = { "prettier" },
                markdown = { "prettier" },
            },
            default_format_opts = { lsp_format = "fallback" },
            format_on_save = function()
                if vim.g.format_on_save then return { timeout_ms = 3000 } end
            end,
        },
    },
}
