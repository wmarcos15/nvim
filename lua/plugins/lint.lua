-- lua/plugins/lint.lua
--
-- Deeper linters that run when you open or save a file. Their findings show
-- up as ordinary diagnostics, next to the language server's.
--
-- Most linting already comes from the language servers while you type
-- (clangd's clang-tidy, ruff, eslint, jdtls). This file adds what those
-- cannot do:
--
--   C / C++   cppcheck               bounds, leaks, undefined behaviour
--             clang-tidy (analyzer)  path-sensitive bugs such as null
--                                    dereferences; clangd skips these checks
--
-- To add a linter for another language, add it to `by_ft` below, e.g.
--   java = { "checkstyle" }
-- (:help lint-linters lists what is supported). A linter whose program is
-- not installed is skipped silently.
local by_ft = {
    c = { "cppcheck", "clangtidy" },
    cpp = { "cppcheck", "clangtidy" },
}

-- clang-tidy ships with LLVM but Homebrew does not put it on PATH.
local function find_clang_tidy()
    for _, path in ipairs({ "clang-tidy", "/opt/homebrew/opt/llvm/bin/clang-tidy", "/usr/local/opt/llvm/bin/clang-tidy" }) do
        if vim.fn.executable(path) == 1 then return path end
    end
end

return {
    {
        "mfussenegger/nvim-lint",
        ft = vim.tbl_keys(by_ft), -- loads when one of those filetypes is opened
        config = function()
            local lint = require("lint")

            local clang_tidy = find_clang_tidy()
            if clang_tidy then
                lint.linters.clangtidy.cmd = clang_tidy
                lint.linters.clangtidy.args = {
                    "--quiet",
                    -- Only the static analyzer: clangd already runs the rest.
                    "--checks=-*,clang-analyzer-*",
                    -- Silence compiler warnings here; clangd reports those.
                    "--extra-arg=-w",
                    function()
                        -- Point at the compilation database when there is one.
                        local root = vim.fs.root(0, { "compile_commands.json", "build/compile_commands.json" })
                        if not root then return "--extra-arg=-Wno-unknown-warning-option" end
                        local in_root = vim.uv.fs_stat(root .. "/compile_commands.json")
                        return "-p=" .. (in_root and root or (root .. "/build"))
                    end,
                }
            end

            -- cppcheck: nvim-lint's parser, our own flags (no "information"
            -- noise about system headers, nothing written into build/).
            lint.linters.cppcheck.args = {
                "--enable=warning,style,performance,portability",
                "--suppress=missingIncludeSystem",
                "--suppress=checkersReport",
                function() return vim.bo.filetype == "cpp" and "--language=c++" or "--language=c" end,
                "--inline-suppr",
                "--quiet",
                "--template={file}:{line}:{column}: [{id}] {severity}: {message}",
            }

            -- Keep only linters whose program exists.
            lint.linters_by_ft = {}
            for ft, names in pairs(by_ft) do
                local available = {}
                for _, name in ipairs(names) do
                    local linter = lint.linters[name]
                    local cmd = type(linter) == "table" and linter.cmd or name
                    if type(cmd) == "function" then cmd = cmd() end
                    if vim.fn.executable(cmd) == 1 then table.insert(available, name) end
                end
                lint.linters_by_ft[ft] = available
            end

            -- These linters read the file from disk, so only lint real, saved files.
            local function run(buf)
                if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then return end
                if not lint.linters_by_ft[vim.bo[buf].filetype] then return end
                if vim.fn.filereadable(vim.api.nvim_buf_get_name(buf)) ~= 1 then return end
                vim.api.nvim_buf_call(buf, function() lint.try_lint() end)
            end
            vim.api.nvim_create_autocmd({ "FileType", "BufWritePost" }, {
                group = vim.api.nvim_create_augroup("UserLint", { clear = true }),
                callback = function(ev) vim.schedule(function() run(ev.buf) end) end,
            })
            run(vim.api.nvim_get_current_buf()) -- the buffer that triggered loading this plugin
        end,
    },
}
