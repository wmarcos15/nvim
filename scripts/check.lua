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
--   * all three theme slots apply; cursor colours follow mode and errors
--   * the orb's marks: error and warning signs become its code, and back
--   * the Orb's memory: note, plan panel, write-on-quit
--   * the speech bubble: reminders, never covers text, goes away
--   * telling the Orb: Space o s / o u through a stand-in orb-say
--   * the start screen opens
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
report(#themes.slots >= 3, "at least 3 theme slots")

-- Cursor colour by mode (slots with `cursor`), and red on errors
local cursor = require("core.cursor")
for i, slot in ipairs(themes.slots) do
    themes.apply(i, { silent = true, temporary = true })
    local themed = vim.o.guicursor:find("ThemeCursor", 1, true) ~= nil
    report(themed == (slot.cursor ~= nil), ("theme slot %d: cursor colours %s"):format(i, slot.cursor and "on" or "off"), vim.o.guicursor)
    if slot.cursor and slot.cursor.error then
        vim.cmd("enew")
        local ns = vim.api.nvim_create_namespace("check_cursor")
        local clean = cursor.normal_color()
        vim.diagnostic.set(ns, 0, { { lnum = 0, col = 0, message = "x", severity = vim.diagnostic.severity.ERROR } })
        local broken = cursor.normal_color()
        vim.wait(100)
        local group_used = vim.o.guicursor:find("ThemeCursorError", 1, true) ~= nil
        vim.diagnostic.set(ns, 0, { { lnum = 0, col = 0, message = "x", severity = vim.diagnostic.severity.WARN } })
        local warned = cursor.state()
        cursor.busy("check", true)
        local busy = cursor.state()
        cursor.busy("check", false)
        vim.diagnostic.reset(ns, 0)
        report(clean == slot.cursor.normal and broken == slot.cursor.error and group_used and cursor.normal_color() == clean,
            ("theme slot %d: cursor turns red on an error and back"):format(i), ("%s -> %s"):format(clean, broken))
        report(warned == "warn" and busy == "busy" and cursor.state() == "normal",
            ("theme slot %d: cursor shows warnings and working"):format(i), ("%s, %s"):format(warned, busy))
        vim.cmd("bwipeout!")
    end
end

-- The orb's marks (lua/core/marks.lua): while the orb shows, error and
-- warning signs become a code that its shader draws as a small dial; when it
-- goes, the signs are exactly as before.
local marks = require("core.marks")
local sev = vim.diagnostic.severity
local CODE = "\u{2580}\u{2580}"
local sign_groups = { "DiagnosticSignError", "DiagnosticSignWarn", "DiagnosticSignInfo", "DiagnosticSignHint" }
local function raw_hl(name) return vim.api.nvim_get_hl(0, { name = name }) end
local function colours(name)
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    return ("%s/%s"):format(hl.fg and ("#%06x"):format(hl.fg) or "none", hl.bg and ("#%06x"):format(hl.bg) or "none")
end

local orb_slot
for i, slot in ipairs(themes.slots) do
    if slot.orb then
        orb_slot = i
        break
    end
end
-- Headless there is no Ghostty: the orb's slot keeps the icons.
themes.apply(orb_slot, { silent = true, temporary = true })
local signs_before = vim.diagnostic.config().signs
local hl_before = {}
for _, name in ipairs(sign_groups) do hl_before[name] = raw_hl(name) end
report(not marks.active() and signs_before.text[sev.ERROR] == "\u{f057}" and signs_before.text[sev.WARN] == "\u{f071}",
    ("theme slot %d without Ghostty: signs keep their icons"):format(orb_slot), tostring(signs_before.text[sev.ERROR]))

marks.set_active(true)
local text = vim.diagnostic.config().signs.text
report(text[sev.ERROR] == CODE and text[sev.WARN] == CODE
        and text[sev.INFO] == signs_before.text[sev.INFO] and text[sev.HINT] == signs_before.text[sev.HINT]
        and colours("DiagnosticSignError") == "#ff6e4e/#ff6e3e" and colours("DiagnosticSignWarn") == "#f1ff4e/#f1ff3e"
        and vim.deep_equal(raw_hl("DiagnosticSignInfo"), hl_before.DiagnosticSignInfo)
        and vim.deep_equal(raw_hl("DiagnosticSignHint"), hl_before.DiagnosticSignHint),
    "orb marks: error and warning signs become the code",
    colours("DiagnosticSignError") .. " " .. colours("DiagnosticSignWarn"))

-- An error and a warning on the same line: the error's code is what shows.
vim.cmd("enew")
local marks_ns = vim.api.nvim_create_namespace("check_marks")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", "three" })
vim.diagnostic.set(marks_ns, 0, {
    { lnum = 1, col = 0, message = "a warning", severity = sev.WARN },
    { lnum = 1, col = 0, message = "a problem", severity = sev.ERROR },
})
vim.cmd("redraw")
local corner = vim.fn.win_screenpos(0)   -- the window's top-left screen cell
local row, col = corner[1] + 1, corner[2] -- buffer line 2; the signs are the window's first two columns
local shown = vim.fn.screenstring(row, col) .. vim.fn.screenstring(row, col + 1)
local top_sign
for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, -1, { 1, 0 }, { 1, -1 }, { details = true, type = "sign" })) do
    if m[4].sign_hl_group and (not top_sign or m[4].priority > top_sign.priority) then top_sign = m[4] end
end
report(shown == CODE and top_sign ~= nil and top_sign.sign_hl_group == "DiagnosticSignError",
    "orb marks: the error beats a warning on the same line",
    shown .. " " .. (top_sign and top_sign.sign_hl_group or "no sign"))

-- Reloading the slot's own colorscheme (Neovim does it when it learns the
-- terminal's background) must not wash the colours out.
vim.cmd.colorscheme(themes.slots[orb_slot].colorscheme)
report(colours("DiagnosticSignError") == "#ff6e4e/#ff6e3e" and colours("DiagnosticSignWarn") == "#f1ff4e/#f1ff3e"
        and themes.current == orb_slot and marks.active(),
    "orb marks: kept through a colorscheme reload", colours("DiagnosticSignError"))

-- Off: the icons and the colorscheme's colours, exactly as before.
marks.set_active(false)
local restored = vim.deep_equal(vim.diagnostic.config().signs, signs_before)
for _, name in ipairs(sign_groups) do
    restored = restored and vim.deep_equal(raw_hl(name), hl_before[name])
end
report(restored and not marks.active(), "orb marks: off puts the icons and colours back", colours("DiagnosticSignError"))
vim.diagnostic.reset(marks_ns, 0)
vim.cmd("bwipeout!")
if before then themes.apply(before, { silent = true, temporary = true }) end

report(vim.fn.maparg("<leader>to", "n") == "", "<leader>to is not mapped")

-- The Orb's memory (lua/core/memory.lua) and its speech bubble
-- (lua/core/bubble.lua). Everything happens in temporary git projects, which
-- are deleted again at the end; the session state, cwd and marks are put back.
do
    local memory = require("core.memory")
    local bubble = require("core.bubble")
    -- The bubble belongs to the Orb's theme slot: test it there.
    local slot_before = themes.current
    themes.apply(orb_slot, { silent = true, temporary = true })
    local start_cwd = vim.fn.getcwd()
    local made = {}

    local function realpath(path) return vim.uv.fs_realpath(path) or path end
    local function make_dir(git)
        local d = vim.fn.tempname()
        vim.fn.mkdir(d, "p")
        d = realpath(d)
        if git then vim.fn.system({ "git", "-C", d, "init", "-q" }) end
        table.insert(made, d)
        return d
    end
    local function put(path, content)
        vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
        vim.fn.writefile(content, path)
    end
    -- The bubble's title as plain text (Neovim gives it back as chunks).
    local function title_chunks(w)
        local t = vim.api.nvim_win_get_config(w).title
        if type(t) == "string" then return { { t } } end
        return t
    end
    local function title_text(w)
        local out = {}
        for _, chunk in ipairs(title_chunks(w)) do table.insert(out, chunk[1]) end
        return table.concat(out)
    end
    local function press(keys) vim.api.nvim_feedkeys(vim.keycode(keys), "mx", false) end

    local proj = make_dir(true)
    vim.cmd("enew")

    -- 1. The note is read without its marker and comments.
    put(proj .. "/.orb/now.md", {
        "<!-- orb: written 2025-01-31 18:40 -->",
        "<!-- a one-line comment -->",
        "Wiring the plan panel.",
        "<!-- a comment",
        "over two lines -->", -- leaves one empty line behind
        "Next, tick boxes.",
        "",
    })
    local note, by_orb = memory.read_note(proj)
    report(note == "Wiring the plan panel.\n\nNext, tick boxes." and by_orb == true,
        "memory: the note is read without its marker and comments", tostring(note))

    -- 2. Saving the note by hand removes the marker.
    local note_win = memory.edit_note(proj)
    local note_buf = vim.api.nvim_win_get_buf(note_win)
    vim.api.nvim_buf_set_lines(note_buf, 1, 2, false, { "My own words." })
    vim.api.nvim_buf_call(note_buf, function() vim.cmd("write") end)
    local on_disk = vim.fn.readfile(proj .. "/.orb/now.md")
    local floating = vim.api.nvim_win_get_config(note_win).relative == "editor"
    press("q")
    report(on_disk[1] ~= nil and not on_disk[1]:match("^<!%-%- orb:") and memory.session.hand_saved[proj] == true
            and floating and not vim.api.nvim_win_is_valid(note_win),
        "memory: saving the note by hand removes the marker", tostring(on_disk[1]))

    -- 3. The plan panel: from the template, x ticks and unticks, q closes and saves.
    local planned = make_dir(true)
    local plan_win, plan_buf = memory.plan(planned)
    local from_template = vim.deep_equal(vim.fn.readfile(planned .. "/.orb/plan.md"), memory.template)
    vim.api.nvim_buf_set_lines(plan_buf, -1, -1, false, { "- [ ] write tests" })
    local item_line = vim.api.nvim_buf_line_count(plan_buf)
    vim.api.nvim_win_set_cursor(plan_win, { item_line, 0 })
    press("x")
    local ticked = vim.fn.readfile(planned .. "/.orb/plan.md")[item_line]
    press("x")
    local unticked = vim.fn.readfile(planned .. "/.orb/plan.md")[item_line]
    vim.api.nvim_buf_set_lines(plan_buf, -1, -1, false, { "- [ ] and more" }) -- unsaved: q must keep it
    press("q")
    local still_mapped = false
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(plan_buf, "n")) do
        if m.lhs == "x" or m.lhs == "q" or m.lhs == "e" then still_mapped = true end
    end
    local saved_on_close = vim.fn.readfile(planned .. "/.orb/plan.md")[item_line + 1]
    report(from_template and ticked == "- [x] write tests" and unticked == "- [ ] write tests"
            and saved_on_close == "- [ ] and more" and not vim.api.nvim_win_is_valid(plan_win) and not still_mapped,
        "memory: the plan panel opens from the template, x ticks and unticks, q closes and saves",
        ("%s | %s | %s | mapped=%s"):format(tostring(ticked), tostring(unticked), tostring(saved_on_close), tostring(still_mapped)))

    -- 4. Write-on-quit starts orb-note for written projects only.
    local stub_dir = make_dir(false)
    local args_file = stub_dir .. "/args"
    put(stub_dir .. "/stub", { "#!/bin/sh", 'echo "$@" > "' .. args_file .. '"' })
    vim.uv.fs_chmod(stub_dir .. "/stub", 493) -- 0755
    local old_note_cmd = vim.env.ORB_NOTE
    vim.env.ORB_NOTE = stub_dir .. "/stub"
    memory.reset_session()
    local function write_in(dirname, name)
        vim.cmd("edit " .. vim.fn.fnameescape(dirname .. "/" .. name))
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "text" })
        vim.cmd("write")
    end
    local plain = make_dir(false)
    write_in(proj, "a.txt")        -- written ...
    memory.session.hand_saved[proj] = true -- ... but its note was saved by hand: skipped
    write_in(planned, "b.txt")     -- written, git: started
    vim.cmd("cd " .. vim.fn.fnameescape(plain))
    write_in(plain, "c.txt")       -- written, no git and no .orb/: skipped
    vim.cmd("cd " .. vim.fn.fnameescape(start_cwd))
    local recorded = memory.session.written[planned] ~= nil and memory.session.written[proj] ~= nil
    local headless_started = memory.on_quit()
    local started = memory.on_quit({ force = true })
    vim.wait(2000, function() return vim.fn.filereadable(args_file) == 1 and #vim.fn.readfile(args_file) > 0 end, 50)
    local args = vim.fn.filereadable(args_file) == 1 and vim.fn.readfile(args_file)[1] or ""
    vim.env.ORB_NOTE = old_note_cmd
    report(recorded and #headless_started == 0 and #started == 1 and started[1] == planned
            and args == ("--since %d %s"):format(memory.started, planned),
        "memory: write-on-quit starts orb-note for written projects only",
        ("started=%s args=%s"):format(table.concat(started, ","), args))
    memory.reset_session()

    -- 5. The bubble says the reminder, titled " orb " while the orb is not showing.
    vim.cmd("enew")
    put(proj .. "/.orb/plan.md", { "# Plan", "", "## Now", "- [ ] step one" })
    memory.remind({ root = proj })
    vim.wait(500, function() return bubble.showing() ~= nil end, 20)
    local said = bubble.showing()
    local bubble_win = bubble.window()
    local plain_title = bubble_win and title_text(bubble_win) or "no window"
    report(said ~= nil and said:find("Last time:", 1, true) ~= nil and said:find("Next: step one", 1, true) ~= nil
            and plain_title == " orb ",
        "bubble: says the reminder", ("%s | title=%q"):format(tostring(said):gsub("\n", " / "), plain_title))
    bubble.clear("memory")

    -- 6. The speaking mark in the title while the orb shows.
    marks.set_active(true)
    bubble.say("x", nil, { source = "check" })
    vim.wait(500, function() return bubble.window() ~= nil end, 20)
    local marked = false
    local shown_title = "no window"
    if bubble.window() then
        shown_title = title_text(bubble.window())
        for _, chunk in ipairs(title_chunks(bubble.window())) do
            if chunk[1] == CODE and chunk[2] == "OrbMarkSpeak" then marked = true end
        end
    end
    bubble.clear("check")
    marks.set_active(false)
    local signs_back = vim.deep_equal(vim.diagnostic.config().signs, signs_before)
    for _, name in ipairs(sign_groups) do
        signs_back = signs_back and vim.deep_equal(raw_hl(name), hl_before[name])
    end
    report(marked and colours("OrbMarkSpeak") == "#5ef1ef/#5ef1df" and signs_back,
        "bubble: the speaking mark in the title while the orb shows",
        ("title=%q %s signs_back=%s"):format(shown_title, colours("OrbMarkSpeak"), tostring(signs_back)))

    -- 7. It never covers text: fill the screen's right half and it has to go.
    bubble.say("hello", nil, { source = "check" })
    vim.wait(300)
    local long = {}
    for i = 1, vim.o.lines do long[i] = string.rep("x", vim.o.columns - 10) end
    vim.api.nvim_buf_set_lines(0, 0, -1, false, long)
    vim.cmd("doautocmd TextChanged")   -- a script's edits do not announce themselves
    vim.wait(300)
    local crowded = bubble.showing()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
    vim.cmd("doautocmd TextChanged")
    vim.wait(300)
    local roomy = bubble.showing()
    bubble.clear("check")
    report(crowded == nil and roomy == "hello", "bubble: never covers text",
        ("crowded=%s roomy=%s"):format(tostring(crowded), tostring(roomy)))

    -- In any other theme slot there is no bubble: a message you asked for
    -- arrives as an ordinary notification instead.
    local other_slot = orb_slot == 1 and 2 or 1
    themes.apply(other_slot, { silent = true, temporary = true })
    local notified, real_notify = nil, vim.notify
    vim.notify = function(msg) notified = msg end
    bubble.say("elsewhere", nil, { source = "check", fallback = true })
    vim.wait(400, function() return notified ~= nil end, 20)
    vim.notify = real_notify
    local hidden = bubble.showing() == nil
    bubble.clear("check")
    themes.apply(orb_slot, { silent = true, temporary = true })
    report(hidden and notified == "elsewhere", "bubble: only in the Orb's theme slot",
        ("slot %d: window=%s notified=%s"):format(other_slot, tostring(not hidden), tostring(notified)))

    -- 8. It goes away: on its timeout, on InsertEnter (reminders only), on clear.
    bubble.say("brief", nil, { source = "check", timeout = 400 })
    local appeared = vim.wait(250, function() return bubble.showing() ~= nil end, 20)
    vim.wait(700)
    local timed_out = bubble.showing() == nil

    bubble.say("reminder", nil, { source = "check", until_insert = true })
    vim.wait(500, function() return bubble.showing() ~= nil end, 20)
    press("i<Esc>")
    vim.wait(300)
    local insert_dropped = bubble.showing() == nil

    bubble.say("keep", nil, { source = "check" })
    vim.wait(500, function() return bubble.showing() ~= nil end, 20)
    press("i<Esc>")
    vim.wait(500, function() return bubble.showing() ~= nil end, 20)
    local kept = bubble.showing() == "keep"

    bubble.clear("check")
    vim.wait(300)
    local cleared = bubble.showing() == nil
    local idle = #vim.api.nvim_get_autocmds({ group = "user_orb_bubble" }) == 0
    report(appeared and timed_out and insert_dropped and kept and cleared and idle,
        "bubble: goes away on timeout, on InsertEnter (reminders only) and on clear",
        ("appeared=%s timeout=%s insert=%s kept=%s clear=%s no_autocmds=%s"):format(
            tostring(appeared), tostring(timed_out), tostring(insert_dropped), tostring(kept), tostring(cleared), tostring(idle)))

    -- 9. No diagnostics voice: an error alone makes the bubble say nothing.
    local voice_ns = vim.api.nvim_create_namespace("check_bubble_voice")
    vim.diagnostic.set(voice_ns, 0, { { lnum = 0, col = 0, message = "bubble check", severity = sev.ERROR } })
    vim.wait(300)
    local voice = bubble.showing()
    vim.diagnostic.reset(voice_ns, 0)
    report(voice == nil, "bubble: no diagnostics voice", tostring(voice))

    -- 10. The Orb keys.
    report(vim.fn.maparg("<leader>on", "n") ~= "" and vim.fn.maparg("<leader>oe", "n") ~= ""
            and vim.fn.maparg("<leader>op", "n") ~= "" and vim.fn.maparg("<leader>os", "n") ~= ""
            and vim.fn.maparg("<leader>ou", "n") ~= "" and vim.fn.maparg("<leader>o", "n") == "",
        "Orb keys: <leader>on, oe, op, os, ou are mapped and <leader>o is not")

    -- 11. The docs page lists the Orb group.
    local docs_ok = pcall(function() return require("core.docs").generate() end)
    local groups_line
    for _, l in ipairs(vim.fn.readfile(vim.fn.stdpath("config") .. "/docs/keymaps.js")) do
        if l:match("^%s*groups:") then groups_line = l end
    end
    report(docs_ok and groups_line ~= nil and groups_line:find('"Orb"', 1, true) ~= nil,
        "docs: the Orb group is in docs/keymaps.js")

    -- 12. The orb-side tool, when installed, writes the marker line first.
    local config_home = vim.env.XDG_CONFIG_HOME
    if not config_home or config_home == "" then config_home = vim.env.HOME .. "/.config" end
    local tool = config_home .. "/orb/bin/orb-note"
    if vim.fn.executable(tool) == 1 then
        local out = vim.fn.systemlist({ tool, "--no-model", "--dry-run", proj })
        report(vim.v.shell_error == 0 and out[1] ~= nil and out[1]:match("^<!%-%- orb: written .- %-%->%s*$") ~= nil,
            "orb-note: --no-model --dry-run starts with the marker", tostring(out[1]))
    else
        report(true, "orb-note: --no-model --dry-run starts with the marker (orb-note not installed: skipped)")
    end

    -- A git project without a note: asking for the reminder has the Orb write
    -- one (here a stand-in for orb-note does) and then say it.
    local fresh = make_dir(true)
    put(stub_dir .. "/writer", { "#!/bin/sh", 'mkdir -p "$1/.orb" && echo "You were testing." > "$1/.orb/now.md"' })
    vim.uv.fs_chmod(stub_dir .. "/writer", 493) -- 0755
    local note_cmd_before = vim.env.ORB_NOTE
    vim.env.ORB_NOTE = stub_dir .. "/writer"
    memory.remind({ root = fresh })
    vim.wait(3000, function() return (bubble.showing() or ""):find("You were testing", 1, true) ~= nil end, 30)
    local written_and_said = bubble.showing()
    vim.env.ORB_NOTE = note_cmd_before
    bubble.clear("memory")
    report(written_and_said ~= nil and written_and_said:find("Last time: You were testing", 1, true) ~= nil,
        "memory: a missing note is written on request, then said", tostring(written_and_said))

    -- Telling the Orb (lua/core/tell.lua), through stand-ins for orb-say.
    -- The stand-in sees: --json -- ROOT TEXT (so $2 is "--", $3 is ROOT) or
    -- --json --undo -- ROOT (so $2 is "--undo").
    local tell = require("core.tell")
    local cursor = require("core.cursor")
    local say_args = stub_dir .. "/say-args"
    put(stub_dir .. "/say", {
        "#!/bin/sh",
        "# Stand-in for orb-say: records its arguments, then answers like an add or an undo.",
        'printf "%s\\n" "$@" > "' .. say_args .. '"',
        'if [ "$2" = "--undo" ]; then',
        "    echo '{\"ok\":true,\"changed\":true,\"kind\":\"undo\",\"line\":\"Undid it\",\"fallback\":false}'",
        "else",
        '    printf "# Plan\\n\\n## Next\\n\\n- [ ] stub step\\n- [ ] old step\\n" > "$3/.orb/plan.md"',
        "    echo '{\"ok\":true,\"changed\":true,\"kind\":\"add\",\"line\":\"Next: stub step\",\"fallback\":false}'",
        "fi",
    })
    put(stub_dir .. "/say-fail", { "#!/bin/sh", "echo 'orb-say: boom' >&2", "exit 1" })
    vim.uv.fs_chmod(stub_dir .. "/say", 493)
    vim.uv.fs_chmod(stub_dir .. "/say-fail", 493)
    local told = make_dir(true)
    put(told .. "/.orb/plan.md", { "# Plan", "", "## Next", "", "- [ ] old step" })
    local old_say_env, real_say, heard = vim.env.ORB_SAY, memory.say, {}
    vim.env.ORB_SAY = stub_dir .. "/say"
    memory.say = function(text) table.insert(heard, text) return text end
    local function reset_told()
        vim.fn.delete(say_args)
        heard = {}
    end

    -- S1. The plan panel shows the change; the cursor is busy meanwhile.
    reset_told()
    local pw, pb = memory.plan(told)
    local started = tell.tell("Next time I'll test it", { root = told })
    local busy_now = cursor.state() == "busy"
    local in_panel = vim.wait(3000, function()
        return vim.tbl_contains(vim.api.nvim_buf_get_lines(pb, 0, -1, false), "- [ ] stub step")
    end, 20)
    vim.wait(3000, function() return cursor.state() ~= "busy" and heard[1] ~= nil end, 20)
    local panel_open = vim.api.nvim_win_is_valid(pw)
    press("q")
    report(started and busy_now and in_panel and cursor.state() ~= "busy" and heard[1] == "Next: stub step" and panel_open,
        "tell: Space o s runs orb say, shows working, reloads the plan panel and says the line",
        ("started=%s busy=%s panel=%s open=%s heard=%s"):format(tostring(started), tostring(busy_now),
            tostring(in_panel), tostring(panel_open), tostring(heard[1])))

    -- S2. The prompt asks "Tell the Orb: " and passes the sentence on.
    reset_told()
    local ui_input, seen = vim.ui.input, nil
    vim.ui.input = function(o, cb) seen = o.prompt; cb("Next time I'll test it") end
    tell.prompt({ root = told })
    vim.wait(3000, function() return vim.fn.filereadable(say_args) == 1 and #heard > 0 end, 20)
    local got = vim.fn.filereadable(say_args) == 1 and vim.fn.readfile(say_args) or {}
    report(seen == "Tell the Orb: " and vim.deep_equal(got, { "--json", "--", told, "Next time I'll test it" }),
        "tell: the prompt is \"Tell the Orb: \" and orb-say gets --json -- ROOT sentence", vim.inspect(got))

    -- S3. Cancelling or an empty answer runs nothing.
    reset_told()
    vim.ui.input = function(_, cb) cb(nil) end
    tell.prompt({ root = told })
    vim.ui.input = function(_, cb) cb("   ") end
    tell.prompt({ root = told })
    vim.wait(300)
    vim.ui.input = ui_input
    report(vim.fn.filereadable(say_args) == 0 and #heard == 0, "tell: cancelling or an empty sentence does nothing")

    -- S4. Undo.
    reset_told()
    tell.undo({ root = told })
    vim.wait(3000, function() return heard[1] ~= nil end, 20)
    got = vim.fn.filereadable(say_args) == 1 and vim.fn.readfile(say_args) or {}
    report(vim.deep_equal(got, { "--json", "--undo", "--", told }) and heard[1] == "Undid it",
        "tell: Space o u runs orb-say --undo and says the line", vim.inspect(got) .. " " .. tostring(heard[1]))

    -- S5. A plan buffer with unsaved edits is refused.
    reset_told()
    local pbuf = vim.fn.bufadd(told .. "/.orb/plan.md")
    vim.fn.bufload(pbuf)
    vim.api.nvim_buf_set_lines(pbuf, -1, -1, false, { "- [ ] typing" })
    local refused = tell.tell("x", { root = told })
    vim.wait(300)
    local refused_ok = refused == false and vim.fn.filereadable(say_args) == 0
        and heard[1] == "The plan has unsaved changes: save it first. Nothing changed."
    vim.api.nvim_buf_delete(pbuf, { force = true })
    report(refused_ok, "tell: unsaved plan edits are never overwritten", tostring(heard[1]))

    -- S6. A failing orb-say is said plainly and the cursor is not left busy.
    reset_told()
    vim.env.ORB_SAY = stub_dir .. "/say-fail"
    tell.tell("anything", { root = told })
    vim.wait(3000, function() return heard[1] ~= nil end, 20)
    vim.wait(500, function() return cursor.state() ~= "busy" end, 20)
    report(heard[1] == "The Orb could not do that: boom" and cursor.state() ~= "busy",
        "tell: a failing orb-say is said plainly", tostring(heard[1]))

    -- S7. The real bubble says the line.
    reset_told()
    memory.say = real_say
    vim.env.ORB_SAY = stub_dir .. "/say"
    vim.cmd("enew")
    tell.tell("again", { root = told })
    local in_bubble = vim.wait(3000, function() return bubble.showing() == "Next: stub step" end, 30)
    bubble.clear("memory")
    report(in_bubble, "tell: the result is said in the Orb's bubble")

    -- S8. The real orb-say, when installed (no model: it adds in your words).
    local say_tool = config_home .. "/orb/bin/orb-say"
    if vim.fn.executable(say_tool) == 1 then
        local real_proj, state = make_dir(true), make_dir(false)
        local env = { XDG_STATE_HOME = state }
        local added = vim.system({ say_tool, "--json", "--no-model", "--", real_proj, "write the tests" },
            { text = true, env = env }):wait()
        local ok_a, a = pcall(vim.json.decode, vim.trim(added.stdout or ""))
        local added_ok = added.code == 0 and ok_a and a.kind == "add" and a.changed == true and a.fallback == true
            and a.line == "Next: write the tests (added in your words: the model was not asked)"
            and memory.next_item(real_proj) == "write the tests"
        local undone = vim.system({ say_tool, "--json", "--undo", "--", real_proj }, { text = true, env = env }):wait()
        local ok_u, u = pcall(vim.json.decode, vim.trim(undone.stdout or ""))
        local undone_ok = undone.code == 0 and ok_u and u.line == 'Undid "Next: write the tests (added in your words: the model was not asked)"'
            and vim.fn.filereadable(real_proj .. "/.orb/plan.md") == 0
        report(added_ok and undone_ok, "orb-say: --no-model adds in your words, --undo takes it back",
            vim.trim(tostring(added.stdout)) .. " | " .. tostring(added.stderr) .. " | " .. vim.trim(tostring(undone.stdout)))
    else
        report(true, "orb-say: --no-model adds in your words, --undo takes it back (orb-say not installed: skipped)")
    end

    vim.env.ORB_SAY = old_say_env
    memory.say = real_say

    -- Put everything back: the theme slot, session state, buffers, cwd, the temporary projects.
    if slot_before then themes.apply(slot_before, { silent = true, temporary = true }) end
    memory.reset_session()
    vim.cmd("cd " .. vim.fn.fnameescape(start_cwd))
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(b)
        for _, d in ipairs(made) do
            if name:sub(1, #d) == d or name:sub(1, #d + 1) == (d .. "/") then
                pcall(vim.api.nvim_buf_delete, b, { force = true })
                break
            end
        end
    end
    vim.cmd("silent! bwipeout!")
    for _, d in ipairs(made) do vim.fn.delete(d, "rf") end
end

-- Start screen
vim.cmd("tabnew")
local start_ok, start_buf = pcall(function() return require("core.start").open() end)
local start_lines = start_ok and #vim.tbl_filter(function(l) return l ~= "" end, vim.api.nvim_buf_get_lines(start_buf, 0, -1, false)) or 0
report(start_ok and start_lines >= 3 and vim.bo.filetype == "start", "start screen opens", start_ok and (start_lines .. " lines") or tostring(start_buf))
report(not require("core.start").wanted(), "start screen stays away when a buffer is in use")
vim.cmd("tabclose!")

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
