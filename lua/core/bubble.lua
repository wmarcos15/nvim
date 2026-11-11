-- lua/core/bubble.lua
--
-- The Orb's speech bubble: a small panel under the orb (top-right corner)
-- where it "says" things. Right now it speaks for the language servers and
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
local timer            -- the typing-out animation
local group = vim.api.nvim_create_augroup("user_orb_bubble", { clear = true })

local borders = { error = "DiagnosticError", warn = "DiagnosticWarn", info = "DiagnosticInfo", hint = "DiagnosticHint" }
local levels = { "error", "warn", "info", "hint" } -- index = vim.diagnostic.severity

--- Where the bubble goes. The orb is a circle in the top-right corner that
--- reaches about half-way down the window (ORB_SIZE and ORB_GAP in
--- ~/.config/orb/orb.glsl), so the bubble hangs just under it, right-aligned.
local function layout()
    local lines, columns = vim.o.lines, vim.o.columns
    local width = math.max(24, math.min(46, math.floor(columns * 0.32)))
    return { row = math.floor(lines * 0.50) + 1, col = columns - 2, width = width }
end

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

local function close()
    if timer then
        timer:stop()
        timer:close()
        timer = nil
    end
    if win and vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    win, shown = nil, nil
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

local function render()
    local m = current()
    local mode = vim.api.nvim_get_mode().mode
    if not (active and M.enabled and m) or not mode:match("^n") then return close() end

    local at = layout()
    local lines = wrap(m.text, at.width - 2, m.footer and 4 or 5)
    if m.footer then table.insert(lines, m.footer) end
    local key = m.level .. "\n" .. (m.title or "") .. "\n" .. table.concat(lines, "\n") .. at.row .. at.col
    if key == shown and win and vim.api.nvim_win_is_valid(win) then return end
    close()
    shown = key

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

local pending = false
local function render_soon()
    if pending then return end
    pending = true
    vim.schedule(function()
        pending = false
        render()
    end)
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
    if not on then return close() end
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
    vim.api.nvim_create_autocmd({ "ModeChanged", "VimResized", "ColorScheme" }, { group = group, callback = render_soon })
    speak_diagnostics()
end

function M.toggle()
    M.enabled = not M.enabled
    render_soon()
    vim.notify("Orb messages " .. (M.enabled and "on" or "off"))
end

return M
