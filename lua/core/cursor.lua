-- lua/core/cursor.lua
--
-- Cursor colour by state, for theme slots that define `cursor` colours
-- (lua/core/themes.lua):
--
--     insert   while inserting or replacing
--     visual   while selecting
--   and in normal mode, the first of these that applies:
--     busy     something is working: a run / build, or a language server
--              that has been busy for more than a moment
--     error    the current buffer has an error (language server or linter)
--     warn     ... or a warning
--     normal   otherwise
--
-- This is more than decoration. A terminal shader cannot be told anything by
-- Neovim, but it can see the cursor's colour, so the Orb (lua/core/orb.lua)
-- draws itself in that colour: the cursor is how the editor's state reaches the
-- background. Insert and visual keep their own colour even when there are
-- errors, so the orb does not flash red at half-typed code.
local M = {}

local colors          -- the active slot's cursor table, or nil when off
local saved_guicursor -- the user's guicursor from before we touched it
local group = vim.api.nvim_create_augroup("user_theme_cursor", { clear = true })
local working = {}    -- who is busy right now: { [name] = true }

local function count(severity)
    return #vim.diagnostic.get(0, { severity = severity })
end

--- The normal-mode state right now: "busy", "error", "warn" or "normal".
function M.state()
    if not colors then return nil end
    if colors.busy and next(working) then return "busy" end
    if colors.error and count(vim.diagnostic.severity.ERROR) > 0 then return "error" end
    if colors.warn and count(vim.diagnostic.severity.WARN) > 0 then return "warn" end
    return "normal"
end

--- What the normal-mode cursor colour is right now (also used by the self-test).
function M.normal_color()
    local state = M.state()
    return state and colors[state]
end

local groups = { normal = "ThemeCursorNormal", warn = "ThemeCursorWarn", error = "ThemeCursorError", busy = "ThemeCursorBusy" }

local last
local function refresh(force)
    if not colors then return end
    local state = M.state()
    if not force and state == last then return end
    last = state
    local text = "#16181a"
    for name, hl in pairs(groups) do
        vim.api.nvim_set_hl(0, hl, { fg = text, bg = colors[name] or colors.normal })
    end
    vim.api.nvim_set_hl(0, "ThemeCursorInsert", { fg = text, bg = colors.insert or colors.normal })
    vim.api.nvim_set_hl(0, "ThemeCursorVisual", { fg = text, bg = colors.visual or colors.normal })
    -- Each state has its own group name, so a change of state changes the
    -- option's value, which is what makes the terminal UI send the new colour.
    vim.o.guicursor = table.concat({
        "n-c-sm:block-" .. groups[state],
        "v:block-ThemeCursorVisual",
        "i-ci-ve:ver25-ThemeCursorInsert",
        "r-cr:hor20-ThemeCursorInsert",
        "o:hor50-" .. groups[state],
        "t:block-blinkon500-blinkoff500-TermCursor",
    }, ",")
end

local pending = false
local function refresh_soon()
    if pending then return end
    pending = true
    vim.schedule(function()
        pending = false
        refresh()
    end)
end

--- Say that `name` (any label) started or finished working. While anything
--- is working, the normal-mode cursor shows the slot's `busy` colour.
function M.busy(name, on)
    working[name] = on and true or nil
    refresh_soon()
end

-- Language servers report progress in bursts (every save, every index step).
-- Only count one as "working" once it has been at it for a moment.
local lsp_timers = {}
local function lsp_progress(ev)
    local value = ev.data and ev.data.params and ev.data.params.value
    local token = ev.data and ev.data.params and tostring(ev.data.params.token)
    if type(value) ~= "table" or not token then return end
    local key = "lsp:" .. tostring(ev.data.client_id) .. ":" .. token
    if value.kind == "begin" then
        lsp_timers[key] = vim.defer_fn(function()
            if lsp_timers[key] then M.busy(key, true) end
        end, 400)
    elseif value.kind == "end" then
        lsp_timers[key] = nil
        M.busy(key, false)
    end
end

--- Turn state colours on. `tbl` = { normal=, insert=, visual=, warn=, error=, busy= } (hex).
function M.enable(tbl)
    if not colors then saved_guicursor = vim.o.guicursor end
    colors = tbl
    vim.api.nvim_clear_autocmds({ group = group })
    vim.api.nvim_create_autocmd({ "DiagnosticChanged", "BufEnter" }, { group = group, callback = refresh_soon })
    vim.api.nvim_create_autocmd("LspProgress", { group = group, callback = lsp_progress })
    vim.api.nvim_create_autocmd("LspDetach", {
        group = group,
        callback = function(ev) -- a server that goes away never sends "end"
            for key in pairs(working) do
                if key:find("^lsp:" .. ev.data.client_id .. ":") then working[key] = nil end
            end
            refresh_soon()
        end,
    })
    -- A colorscheme reload clears our highlight groups: put them back.
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = function() vim.schedule(function() refresh(true) end) end,
    })
    refresh(true)
end

--- Turn state colours off and restore the previous cursor.
function M.disable()
    if not colors then return end
    colors, last = nil, nil
    vim.api.nvim_clear_autocmds({ group = group })
    if saved_guicursor then vim.o.guicursor = saved_guicursor end
end

return M
