-- lua/core/bubble.lua
--
-- The Orb's speech bubble: a small panel under the orb (top-right corner)
-- where it "says" short things. Today that means the "where you left off"
-- reminder from lua/core/memory.lua. It never covers text: it looks at the
-- screen and settles on an empty patch along the right edge (under the orb
-- if it can), steps aside while you scroll or edit, and stays away if there
-- is no room. It is only shown in normal mode, and it works in every theme
-- slot and terminal: it does not depend on the orb being on screen.
--
-- The title carries the speaking mark: while the orb shows (marks.active()),
-- two "▀" cells in the reserved colours #5ef1ef / #5ef1df, which the orb's
-- shader redraws as a small cyan dial (see "Marks" in ~/.config/orb/README.md).
-- Otherwise the title is the plain text " orb ".
--
--     local bubble = require("core.bubble")
--     bubble.say("Last time: wired the plan panel", nil, { source = "memory", timeout = 12000 })
--     bubble.clear("memory")
--
--   level    nil | "error" | "warn" | "info" | "hint"; colours the outline
--            (nil keeps the ordinary FloatBorder)
--   opts.source        who is speaking; each source holds one message, and
--                      the newest message wins (default "user")
--   opts.timeout       ms; the message removes itself
--   opts.until_insert  the message goes away when you enter insert mode
--   opts.fallback      if there is no free spot, vim.notify(text) once
--
-- The bubble closes by timeout, by InsertEnter (until_insert), by clear(), or
-- when the note float or plan panel opens (memory.lua clears "memory"). While
-- there is no free spot it stays hidden, and comes back when there is one.
local M = {}

local messages = {}    -- source -> { text=, level=, seq=, until_insert=, fallback=, notified= }
local seq = 0
local win, buf, shown  -- the float, its buffer, and the message it holds
local box              -- the screen rows the float covers: { top, bottom }
local wanted = 0       -- counts requests to (re)place the bubble; the latest wins
local timer            -- the typing-out animation
local group = vim.api.nvim_create_augroup("user_orb_bubble", { clear = true })
local listening = false -- are the refresh autocmds installed?

local borders = { error = "DiagnosticError", warn = "DiagnosticWarn", info = "DiagnosticInfo", hint = "DiagnosticHint" }

local function wrap(text, width, max_lines)
    local out = {}
    for _, paragraph in ipairs(vim.split(text, "\n", { trimempty = true })) do
        local line = ""
        for word in paragraph:gmatch("%S+") do
            if #line > 0 and #line + 1 + #word > width then
                table.insert(out, line)
                line = word
            else
                line = #line > 0 and (line .. " " .. word) or word
            end
        end
        if #line > 0 then table.insert(out, line) end
    end
    if #out > max_lines then
        out = vim.list_slice(out, 1, max_lines)
        out[max_lines] = out[max_lines]:sub(1, width - 2) .. " …"
    end
    return out
end

--- The screen row the cursor is on (worked out from the window, so it is
--- right even before the screen has been redrawn).
local function cursor_row()
    return vim.fn.win_screenpos(0)[1] + vim.fn.winline() - 1
end

--- For each screen row, the rightmost column that holds text, looking only at
--- the `reach` columns nearest the right edge. Reads the screen itself, so
--- code, inlay hints, blame text and other panels all count. The cursor's row
--- counts as full: text tends to turn up there (blame, diagnostics).
local function text_edges(reach)
    local columns, edges = vim.o.columns, {}
    for row = 1, vim.o.lines do
        edges[row] = columns - reach
        for col = columns, columns - reach + 1, -1 do
            local cell = vim.fn.screenstring(row, col)
            if cell ~= "" and cell ~= " " then
                edges[row] = col
                break
            end
        end
    end
    edges[cursor_row()] = columns
    return edges
end

--- Where the bubble goes: { row, col, width, lines }, or nil if every spot
--- would cover text. The orb is a circle in the top-right corner reaching
--- about half-way down (ORB_SIZE, ORB_GAP in ~/.config/orb/orb.glsl), so the
--- first choice is just under it; then further down, then up, then narrower.
local function place(m)
    local screen_lines, columns = vim.o.lines, vim.o.columns
    local col = columns - 2                                   -- the panel's right edge
    local last = screen_lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0)
    local wide = math.max(24, math.min(46, math.floor(columns * 0.32)))
    local edges = text_edges(wide + 8)
    local first = math.floor(screen_lines * 0.50) + 1
    for _, width in ipairs(wide > 24 and { wide, 24 } or { wide }) do
        local lines = wrap(m.text, width - 2, 6)
        local height = #lines + 2                             -- with the outline
        local left = col - width - 2                          -- leftmost column it may touch
        local function free(row)                              -- row: 0-based top of the panel
            if row < 1 or row + height > last then return false end
            for r = row + 1, row + height do
                if edges[r] >= left - 1 then return false end -- keep one column of air
            end
            return true
        end
        local rows = {}
        for row = first, last do table.insert(rows, row) end
        for row = first - 1, 1, -1 do table.insert(rows, row) end
        for _, row in ipairs(rows) do
            if free(row) then return { row = row, col = col, width = width, lines = lines } end
        end
    end
end

local function close()
    if timer then
        timer:stop()
        timer:close()
        timer = nil
    end
    if win and vim.api.nvim_win_is_valid(win) then
        local old = win
        win = nil                                   -- so that our own WinClosed is not news
        vim.api.nvim_win_close(old, true)
    end
    win, shown, box = nil, nil, nil
end

--- The message to show right now: the newest, or nil.
local function current()
    local best
    for _, m in pairs(messages) do
        if not best or m.seq > best.seq then best = m end
    end
    return best
end

--- The window title: the speaking mark while the orb shows, else " orb ".
local function title()
    -- marks.active() is true exactly while the shader can decode marks (after
    -- themes.lua's short delay), so a plain block never flashes in the title.
    local ok, marks = pcall(require, "core.marks")
    if ok and marks.active() then
        -- Reserved colours: keep in step with orb.glsl (SETTINGS).
        vim.api.nvim_set_hl(0, "OrbMarkSpeak", { fg = "#5ef1ef", bg = "#5ef1df" })
        return { { " ", "FloatTitle" }, { "\u{2580}\u{2580}", "OrbMarkSpeak" }, { " ", "FloatTitle" } }
    end
    return " orb "
end

--- Put the bubble on screen for the current message (the screen must be up
--- to date and the old bubble gone: see refresh()).
local function open()
    local m = current()
    local mode = vim.api.nvim_get_mode().mode
    if not m or not mode:match("^n") then return end
    vim.cmd("redraw")
    local at = place(m)
    if not at then
        -- No free spot: tell the user the plain way, once per message.
        if m.fallback and not m.notified then
            m.notified = true
            vim.notify(m.text)
        end
        return
    end
    local lines = at.lines
    shown = m
    box = { top = at.row + 1, bottom = at.row + #lines + 2 }

    buf = (buf and vim.api.nvim_buf_is_valid(buf)) and buf or vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "hide"
    local border = borders[m.level] or "FloatBorder"
    win = vim.api.nvim_open_win(buf, false, {
        relative = "editor", anchor = "NE", row = at.row, col = at.col,
        width = at.width, height = #lines,
        style = "minimal", border = "rounded", focusable = false, noautocmd = true, zindex = 20,
        title = title(), title_pos = "right",
    })
    vim.wo[win].winhighlight = ("FloatBorder:%s,FloatTitle:FloatTitle,NormalFloat:NormalFloat"):format(border)
    vim.wo[win].wrap = false

    -- The orb "types" the message out: a few characters every few milliseconds.
    local total = #table.concat(lines, "\n")
    local step = math.max(2, math.ceil(total / 22))
    local n = 0
    local function draw()
        if not (win and vim.api.nvim_win_is_valid(win)) then return true end
        n = math.min(total, n + step)
        local left, out = n, {}
        for _, line in ipairs(lines) do
            table.insert(out, " " .. line:sub(1, math.max(left, 0)))
            left = left - #line - 1
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
        return n >= total
    end
    if not draw() then
        timer = vim.uv.new_timer()
        timer:start(16, 16, vim.schedule_wrap(function()
            if timer and draw() then
                timer:stop()
                timer:close()
                timer = nil
            end
        end))
    end
end

--- Take the bubble away and, once the screen has settled, find it a place
--- again. Called whenever the message or what is on screen may have changed.
local function refresh()
    close()
    wanted = wanted + 1
    local mine = wanted
    vim.defer_fn(function()
        if mine == wanted then open() end
    end, 100)
end

--- The same, unless the bubble already shows the current message.
local function render_soon()
    if win and vim.api.nvim_win_is_valid(win) and shown == current() then return end
    refresh()
end

-- With nothing left to say, drop the autocmds (they would only run for nothing).
local function clear_if_idle()
    if next(messages) ~= nil then return end
    listening = false
    vim.api.nvim_clear_autocmds({ group = group })
end

-- The autocmds only exist while there is something to say.
local function listen()
    if listening then return end
    listening = true
    -- What is on screen changed: step aside, then look for room again.
    vim.api.nvim_create_autocmd(
        { "WinScrolled", "TextChanged", "BufWinEnter", "WinNew", "WinClosed", "TabEnter", "ModeChanged", "VimResized", "ColorScheme" },
        { group = group, callback = function(ev)
            if ev.event == "WinClosed" and not win then return end   -- that was the bubble itself
            refresh()
            -- A theme switch turns the marks on a moment later (themes.lua):
            -- look again then, so the title picks up the mark.
            if ev.event == "ColorScheme" then vim.defer_fn(refresh, 300) end
        end })
    -- The cursor walked into the bubble's rows: move out of its way.
    vim.api.nvim_create_autocmd("CursorMoved", {
        group = group,
        callback = function()
            local row = cursor_row()
            if box and row >= box.top and row <= box.bottom then refresh() end
        end,
    })
    -- Reminders last only until you start typing.
    vim.api.nvim_create_autocmd("InsertEnter", {
        group = group,
        callback = function()
            for source, m in pairs(messages) do
                if m.until_insert then messages[source] = nil end
            end
            clear_if_idle()
            render_soon()
        end,
    })
end

--- Say `text` in the bubble (up to six lines; longer text is cut). See the
--- top of this file for `level` and `opts`.
function M.say(text, level, opts)
    opts = opts or {}
    local source = opts.source or "user"
    seq = seq + 1
    local mine = seq
    messages[source] = {
        text = text, level = level, seq = mine,
        until_insert = opts.until_insert, fallback = opts.fallback,
    }
    listen()
    if opts.timeout then
        vim.defer_fn(function()
            if messages[source] and messages[source].seq == mine then M.clear(source) end
        end, opts.timeout)
    end
    render_soon()
end

--- Remove the message of `source` (default "user").
function M.clear(source)
    messages[source or "user"] = nil
    clear_if_idle()
    render_soon()
end

--- What the bubble shows right now: text, level (for the self-test), or nil.
function M.showing()
    local m = current()
    if not (m and win and vim.api.nvim_win_is_valid(win)) then return nil end
    return m.text, m.level
end

--- The bubble's window, or nil (for the self-test: title inspection).
function M.window()
    if win and vim.api.nvim_win_is_valid(win) then return win end
end

return M
