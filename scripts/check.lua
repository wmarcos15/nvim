-- scripts/check.lua
--
-- Self-test for this config. Run from the config folder:
--
--     nvim --headless -c "luafile scripts/check.lua"
--
-- It opens one sample file per language (scripts/samples/) and checks that
--   * the expected language servers attach
--   * treesitter highlighting is active
--   * the expected linters report something on the deliberately buggy samples
--   * no keymap is a prefix of another (which would cause a timeoutlen delay)
--   * the keymap docs generate
--   * all three theme slots apply
-- Exit code 0 = everything passed. Java is slow the first time (jdtls builds
-- its workspace), so allow a minute or two.
local dir = vim.fn.stdpath("config") .. "/scripts/samples/"
local failures, lines = 0, {}

local function report(ok, what, detail)
    if not ok then failures = failures + 1 end
    table.insert(lines, ("%s  %s%s"):format(ok and "PASS" or "FAIL", what, detail and ("  (" .. detail .. ")") or ""))
end

local function client_names(buf)
    local names = {}
    for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do names[c.name] = true end
    return names
end

local function diagnostic_sources(buf)
    local sources = {}
    for _, d in ipairs(vim.diagnostic.get(buf)) do
        sources[(d.source or "?"):lower()] = true
    end
    return sources
end

-- No normal-mode keymap this config defines may be a strict prefix of another
-- mapped key (or the other way round).
local function prefix_conflicts(buf)
    local mine = {}
    for _, e in ipairs(require("core.keymaps").registry) do
        if vim.tbl_contains(e.modes, "n") and not e.recorded and e.keys ~= "<Space>" then
            mine[vim.api.nvim_replace_termcodes(e.keys, true, true, true)] = e.keys
        end
    end
    local live = {}
    for _, m in ipairs(vim.api.nvim_get_keymap("n")) do live[m.lhsraw] = m.lhs end
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do live[m.lhsraw] = m.lhs end
    live[" "] = nil -- <Space> is the leader itself

    local found = {}
    for raw, name in pairs(mine) do
        for other, other_name in pairs(live) do
            if other ~= raw and (other:sub(1, #raw) == raw or raw:sub(1, #other) == other) then
                local pair = { name, vim.fn.keytrans(other) }
                table.sort(pair)
                found[pair[1] .. " <-> " .. pair[2]] = true
            end
        end
    end
    return vim.tbl_keys(found)
end

local samples = {
    { file = "sample.c", servers = { "clangd" }, linters = { "cppcheck", "clang-tidy" }, wait = 40 },
    { file = "sample.cpp", servers = { "clangd" }, wait = 20 },
    { file = "sample.py", servers = { "pyright", "ruff" }, linters = { "ruff" }, wait = 30 },
    { file = "sample.ts", servers = { "vtsls" }, wait = 40 },
    { file = "sample.js", servers = { "vtsls" }, wait = 40 },
    { file = "Sample.java", servers = { "jdtls" }, wait = 180 },
}

for _, s in ipairs(samples) do
    vim.cmd.edit(dir .. s.file)
    local buf = vim.api.nvim_get_current_buf()

    local attached = vim.wait(s.wait * 1000, function()
        local names = client_names(buf)
        for _, want in ipairs(s.servers) do
            if not names[want] then return false end
        end
        return true
    end, 200)
    report(attached, s.file .. ": language servers " .. table.concat(s.servers, " + "),
        not attached and ("attached: " .. table.concat(vim.tbl_keys(client_names(buf)), ", ")) or nil)

    report(vim.treesitter.highlighter.active[buf] ~= nil, s.file .. ": treesitter highlighting")

    if s.linters then
        local seen = vim.wait(s.wait * 1000, function()
            local sources = diagnostic_sources(buf)
            for _, want in ipairs(s.linters) do
                if not sources[want] then return false end
            end
            return true
        end, 200)
        report(seen, s.file .. ": diagnostics from " .. table.concat(s.linters, " + "),
            not seen and ("got: " .. table.concat(vim.tbl_keys(diagnostic_sources(buf)), ", ")) or nil)
    end

    local conflicts = prefix_conflicts(buf)
    report(#conflicts == 0, s.file .. ": no keymap prefix conflicts",
        #conflicts > 0 and table.concat(conflicts, "; ") or nil)
end

-- Text objects exist in a buffer with a parser
vim.cmd.edit(dir .. "sample.cpp")
report(vim.fn.maparg("]f", "n") ~= "" and vim.fn.maparg("af", "x") ~= "" and vim.fn.maparg("<leader>sn", "n") ~= "",
    "treesitter text objects are mapped (]f, af, <leader>sn)")

-- Git keymaps attach in a tracked file
vim.wait(3000, function() return vim.fn.maparg("<leader>gs", "n") ~= "" end, 100)
report(vim.fn.maparg("<leader>gs", "n") ~= "", "git keymaps attach (<leader>gs)")

-- Formatters resolve
for _, case in ipairs({ { "sample.cpp", "clang-format" }, { "sample.py", "ruff_format" }, { "sample.ts", "prettier" } }) do
    vim.cmd.edit(dir .. case[1])
    local names = {}
    for _, f in ipairs(require("conform").list_formatters(0)) do
        if f.available then names[f.name] = true end
    end
    report(names[case[2]] == true, case[1] .. ": formatter " .. case[2] .. " available")
end

-- Docs
local ok, count = pcall(function() return require("core.docs").generate() end)
report(ok and type(count) == "number" and count > 50, "keymap docs generate", ok and (count .. " keymaps") or tostring(count))

-- Themes
local themes = require("core.themes")
local before = themes.current
for i, slot in ipairs(themes.slots) do
    local applied = themes.apply(i, { silent = true, temporary = true })
    report(applied and vim.g.colors_name ~= nil, ("theme slot %d applies (%s)"):format(i, slot.name), vim.g.colors_name)
end
if before then themes.apply(before, { silent = true, temporary = true }) end
report(#themes.slots >= 3, "at least 3 theme slots")

-- Anything that went wrong along the way
local messages = vim.fn.execute("messages")
local errors = {}
for line in messages:gmatch("[^\n]+") do
    if line:match("^E%d+:") or line:match("[Ee]rror") or line:match("stack traceback") then table.insert(errors, line) end
end
report(#errors == 0, "no error messages", #errors > 0 and table.concat(errors, " | "):sub(1, 400) or nil)

table.insert(lines, failures == 0 and "\nAll checks passed." or ("\n" .. failures .. " check(s) failed."))
io.stdout:write(table.concat(lines, "\n") .. "\n")
vim.cmd(failures == 0 and "qa!" or "cq!")
