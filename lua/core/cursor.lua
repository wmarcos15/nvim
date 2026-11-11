-- lua/core/cursor.lua
--
-- Cursor colour by mode, for theme slots that define `cursor` colours
-- (lua/core/themes.lua):
--
--     normal   the usual colour
--     insert   while inserting or replacing
--     visual   while selecting
--     error    normal mode, when the current buffer has an error diagnostic
--              (from a language server or a linter)
--
-- This is more than decoration. A terminal shader cannot be told anything by
-- Neovim, but it can see the cursor's colour, so shaders/hud.glsl draws its
-- dial in that colour: the cursor is how the editor's state reaches the
-- background. Insert and visual keep their own colour even when there are
-- errors, so the dial does not flash red at half-typed code.
local M = {}

local colors          -- the active slot's cursor table, or nil when off
local saved_guicursor -- the user's guicursor from before we touched it
local group = vim.api.nvim_create_augroup("user_theme_cursor", { clear = true })

local function has_errors()
    return #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR }) > 0
end

--- What the normal-mode cursor colour is right now (also used by the self-test).
function M.normal_color()
    if not colors then return nil end
    return (colors.error and has_errors()) and colors.error or colors.normal
end

local last
local function refresh(force)
    if not colors then return end
    local normal = M.normal_color()
    if not force and normal == last then return end
    last = normal
    local text = "#16181a"
    local errors = colors.error ~= nil and normal == colors.error
    vim.api.nvim_set_hl(0, "ThemeCursorNormal", { fg = text, bg = colors.normal })
    vim.api.nvim_set_hl(0, "ThemeCursorError", { fg = text, bg = colors.error or colors.normal })
    vim.api.nvim_set_hl(0, "ThemeCursorInsert", { fg = text, bg = colors.insert or colors.normal })
    vim.api.nvim_set_hl(0, "ThemeCursorVisual", { fg = text, bg = colors.visual or colors.normal })
    -- A different group name for the error state changes the option's value,
    -- which is what makes the terminal UI send the new colour.
    vim.o.guicursor = table.concat({
        "n-c-sm:block-" .. (errors and "ThemeCursorError" or "ThemeCursorNormal"),
        "v:block-ThemeCursorVisual",
        "i-ci-ve:ver25-ThemeCursorInsert",
        "r-cr:hor20-ThemeCursorInsert",
        "o:hor50-ThemeCursorNormal",
        "t:block-blinkon500-blinkoff500-TermCursor",
    }, ",")
end

--- Turn mode colours on. `tbl` = { normal=, insert=, visual=, error= } (hex).
function M.enable(tbl)
    if not colors then saved_guicursor = vim.o.guicursor end
    colors = tbl
    vim.api.nvim_clear_autocmds({ group = group })
    local pending = false
    vim.api.nvim_create_autocmd({ "DiagnosticChanged", "BufEnter" }, {
        group = group,
        callback = function()
            if pending then return end
            pending = true
            vim.schedule(function()
                pending = false
                refresh()
            end)
        end,
    })
    -- A colorscheme reload clears our highlight groups: put them back.
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = function() vim.schedule(function() refresh(true) end) end,
    })
    refresh(true)
end

--- Turn mode colours off and restore the previous cursor.
function M.disable()
    if not colors then return end
    colors, last = nil, nil
    vim.api.nvim_clear_autocmds({ group = group })
    if saved_guicursor then vim.o.guicursor = saved_guicursor end
end

return M
