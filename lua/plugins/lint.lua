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
-- The analyzer comes in two depths, because the thorough one takes seconds:
--
--   on save      quick: each function on its own. Finishes in about the time
--                it takes to compile the file once.
--   <leader>cl   deep (:LintDeep): also follows calls from one function into
--                another, which finds more and takes several times longer.
--                Its findings stay until the next save.
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
                local args = {
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

                -- Homebrew clang-tidy can't find the macOS SDK on its own (CMake 4 no
                -- longer writes -isysroot into compile_commands.json), so pass it.
                if vim.fn.has("mac") == 1 then
                    local sdk = vim.fn.trim(vim.fn.system({ "xcrun", "--show-sdk-path" }))
                    if vim.v.shell_error == 0 and sdk ~= "" then
                        table.insert(args, "--extra-arg=-isysroot" .. sdk)
                    end
                end

                -- The deep analyzer is the same program under a second name,
                -- so its findings are kept apart from the quick one's.
                lint.linters.clangtidy_deep = vim.tbl_extend("force", {}, lint.linters.clangtidy, { args = args })
                -- Quick = the analyzer's "shallow" mode (no following of calls).
                lint.linters.clangtidy.args = vim.list_extend(vim.deepcopy(args), {
                    "--extra-arg=-Xclang", "--extra-arg=-analyzer-config",
                    "--extra-arg=-Xclang", "--extra-arg=mode=shallow",
                })
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
                -- What the deep analyzer said was about the file as it was.
                vim.diagnostic.reset(lint.get_namespace("clangtidy_deep"), buf)
                vim.api.nvim_buf_call(buf, function() lint.try_lint() end)
            end

            -- The deep analyzer, on request, on the file as saved.
            vim.api.nvim_create_user_command("LintDeep", function()
                local buf = vim.api.nvim_get_current_buf()
                if not (clang_tidy and by_ft[vim.bo[buf].filetype]) then
                    return vim.notify("LintDeep: nothing deeper for this kind of file")
                end
                if vim.bo[buf].modified then return vim.notify("LintDeep: save the file first") end
                -- Its findings include the quick ones: show each only once.
                vim.diagnostic.reset(lint.get_namespace("clangtidy"), buf)
                lint.try_lint("clangtidy_deep")
                vim.notify("Deep lint running…")
            end, { desc = "Run the full static analyzer on this file" })
            vim.api.nvim_create_autocmd({ "FileType", "BufWritePost" }, {
                group = vim.api.nvim_create_augroup("UserLint", { clear = true }),
                callback = function(ev) vim.schedule(function() run(ev.buf) end) end,
            })
            run(vim.api.nvim_get_current_buf()) -- the buffer that triggered loading this plugin
        end,
    },
}
