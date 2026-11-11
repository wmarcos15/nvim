-- lua/core/bubble.lua
--
-- The Orb's speech bubble: a small panel under the orb (top-right corner)
-- where it "says" things. It never covers text: it looks at the screen and
-- settles on an empty patch along the right edge (under the orb if it can),
-- steps aside while you scroll or edit, and stays away if there is no room. Right now it speaks for the language servers and
-- linters: the error or warning on the cursor's line, or else the worst one
-- in the file. Only shown in normal mode, and only while the orb is.
--
-- Anything can speak through it:
--
--     require("core.bubble").say("Build finished", "info", { source = "build", timeout = 4000 })
--     require("core.bubble").clear("build")
--
--   level    "error" | "warn" | "info" | "hint"   (colours the outline)
--   source   who is speaking; each source holds one message. The newest
--            message wins, except that diagnostics always give way to others.
--   title    optional label in the outline (defaults to the source)
--   timeout  optional, ms: the message removes itself
--
-- <leader>to switches the bubble off and on.
local M = {}

M.enabled = true       -- the user's switch (<leader>to)
local active = false   -- is the orb showing? (set by the theme slot)
local messages = {}    -- source -> { text=, level=, title=, seq= }
local seq = 0
local win, buf, shown  -- the float, its buffer, and the text it holds
local box              -- the screen rows the float covers: { top, bottom }
local wanted = 0       -- counts requests to (re)place the bubble; the latest wins
local timer            -- the typing-out animation
local group = vim.api.nvim_create_augroup("user_orb_bubble", { clear = true })

local borders = { error = "DiagnosticError", warn = "DiagnosticWarn", info = "DiagnosticInfo", hint = "DiagnosticHint" }
local levels = { "error", "warn", "info", "hint" } -- index = vim.diagnostic.severity

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
        local lines = wrap(m.text, width - 2, m.footer and 4 or 5)
        if m.footer then table.insert(lines, m.footer) end
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

--- The message to show right now, or nil.
local function current()
    local best
    for source, m in pairs(messages) do
        local rank = (source == "diagnostics" and 0 or 1e9) + m.seq
        if not best or rank > best.rank then best = { rank = rank, m = m } end
    end
    return best and best.m
end

--- Put the bubble on screen for the current message (the screen must be up
--- to date and the old bubble gone: see refresh()).
local function open()
    local m = current()
    local mode = vim.api.nvim_get_mode().mode
    if not (active and M.enabled and m) or not mode:match("^n") then return end
    vim.cmd("redraw")
    local at = place(m)
    if not at then return end
    local lines = at.lines
    shown = m
    box = { top = at.row + 1, bottom = at.row + #lines + 2 }

    buf = (buf and vim.api.nvim_buf_is_valid(buf)) and buf or vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "hide"
    local border = borders[m.level] or borders.info
    win = vim.api.nvim_open_win(buf, false, {
        relative = "editor", anchor = "NE", row = at.row, col = at.col,
        width = at.width, height = #lines,
        style = "minimal", border = "rounded", focusable = false, noautocmd = true, zindex = 20,
        title = m.title and (" " .. m.title .. " ") or nil, title_pos = m.title and "right" or nil,
    })
    vim.wo[win].winhighlight = ("FloatBorder:%s,FloatTitle:%s,NormalFloat:NormalFloat"):format(border, border)
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

--- Say `text` in the bubble (up to five lines; longer text is cut). See the top of this file for `level` and `opts`.
function M.say(text, level, opts)
    opts = opts or {}
    local source = opts.source or "user"
    seq = seq + 1
    local mine = seq
    messages[source] = { text = text, level = level or "info", title = opts.title or source, seq = mine }
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
    render_soon()
end

--- What the bubble shows right now: text, level (for the self-test), or nil.
function M.showing()
    local m = current()
    if not (m and win and vim.api.nvim_win_is_valid(win)) then return nil end
    return m.text, m.level
end

-- ── The diagnostics voice ──────────────────────────────────────────────
local function speak_diagnostics()
    local all = vim.diagnostic.get(0, { severity = { min = vim.diagnostic.severity.WARN } })
    if #all == 0 then
        if messages.diagnostics then M.clear("diagnostics") end
        return
    end
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local pick
    for _, d in ipairs(all) do
        local better = not pick
            or ((d.lnum == row) ~= (pick.lnum == row) and d.lnum == row)                -- on this line first
            or ((d.lnum == row) == (pick.lnum == row) and (d.severity < pick.severity   -- then the worst
                or (d.severity == pick.severity and d.lnum < pick.lnum)))               -- then the first
        if better then pick = d end
    end
    local text = ("Line %d: %s"):format(pick.lnum + 1, (pick.message:gsub("%s+", " ")))
    local footer = #all > 1 and ("+%d more in this file"):format(#all - 1) or nil
    local level = levels[pick.severity] or "info"
    local old = messages.diagnostics
    if old and old.text == text and old.level == level and old.footer == footer then return end
    seq = seq + 1
    messages.diagnostics = { text = text, footer = footer, level = level, title = pick.source or level, seq = seq }
    render_soon()
end

--- The theme slot calls this: the bubble only exists while the orb shows.
function M.set_active(on)
    active = on
    vim.api.nvim_clear_autocmds({ group = group })
    if not on then
        wanted = wanted + 1
        return close()
    end
    local debounce
    vim.api.nvim_create_autocmd({ "DiagnosticChanged", "BufEnter", "CursorHold" }, {
        group = group,
        callback = function()
            if debounce then return end
            debounce = true
            vim.defer_fn(function()
                debounce = false
                speak_diagnostics()
            end, 60)
        end,
    })
    -- What is on screen changed: step aside, then look for room again.
    vim.api.nvim_create_autocmd(
        { "WinScrolled", "TextChanged", "BufWinEnter", "WinNew", "WinClosed", "TabEnter", "ModeChanged", "VimResized", "ColorScheme" },
        { group = group, callback = function(ev)
            if ev.event == "WinClosed" and not win then return end   -- that was the bubble itself
            refresh()
        end })
    -- The cursor walked into the bubble's rows: move out of its way.
    vim.api.nvim_create_autocmd("CursorMoved", {
        group = group,
        callback = function()
            local row = cursor_row()
            if box and row >= box.top and row <= box.bottom then refresh() end
        end,
    })
    speak_diagnostics()
end

function M.toggle()
    M.enabled = not M.enabled
    render_soon()
    vim.notify("Orb messages " .. (M.enabled and "on" or "off"))
end

return M
