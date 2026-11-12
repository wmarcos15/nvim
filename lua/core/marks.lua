-- lua/core/marks.lua
--
-- The Orb's marks: a small copy of the dial in the sign column on every line
-- that has an error (red) or a warning (yellow).
--
-- Neovim cannot draw the dial, but the Orb's shader (~/.config/orb/orb.glsl)
-- can, if it is shown where. So while the orb is showing, the error and
-- warning signs become a code: two upper half blocks ("▀▀") in colours kept
-- for nothing else (see "Marks" in ~/.config/orb/README.md). The shader
-- finds the code on the screen and draws the dial over it. Which lines get a
-- sign, and that an error beats a warning on the same line, is Neovim's own
-- doing (vim.diagnostic, with severity_sort in lua/plugins/lsp.lua).
--
-- Only the error and warning signs change. Info and hint signs, the virtual
-- text, the underline and the ]d float stay as they are. When the orb goes
-- (another slot, another terminal) the signs get back exactly what they had:
-- the Nerd Font icons from lua/plugins/lsp.lua and the colorscheme's colours.
--
-- lua/core/themes.lua switches this on and off with set_active().
local M = {}

local CODE = "\u{2580}\u{2580}" -- the foreground paints the top half, the background the bottom half

-- The reserved colours. Keep them in step with orb.glsl (SETTINGS).
M.colours = {
    DiagnosticSignError = { fg = "#ff6e4e", bg = "#ff6e3e" },
    DiagnosticSignWarn  = { fg = "#f1ff4e", bg = "#f1ff3e" },
}
local severities = { vim.diagnostic.severity.ERROR, vim.diagnostic.severity.WARN }

local on = false
local saved_signs     -- the `signs` part of vim.diagnostic.config() from before
local saved_hl = {}   -- highlight group -> what the colorscheme had (may be a link)
local group = vim.api.nvim_create_augroup("user_orb_marks", { clear = true })

--- Does highlight group `name` hold the reserved colours right now?
local function ours(name)
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    local want = M.colours[name]
    return hl.fg == tonumber(want.fg:sub(2), 16) and hl.bg == tonumber(want.bg:sub(2), 16)
end

--- Put the reserved colours in, remembering what the colorscheme had.
local function paint()
    for name, colours in pairs(M.colours) do
        if not ours(name) then saved_hl[name] = vim.api.nvim_get_hl(0, { name = name }) end
        vim.api.nvim_set_hl(0, name, colours)
    end
end

--- Switch the marks on (the orb is showing) or off.
function M.set_active(want)
    want = want and true or false
    if want == on then return end
    on = want
    vim.api.nvim_clear_autocmds({ group = group })
    if on then
        saved_signs = vim.diagnostic.config().signs
        if saved_signs == nil then saved_signs = true end -- Neovim's default
        local signs = type(saved_signs) == "table" and vim.deepcopy(saved_signs) or {}
        signs.text = signs.text or {}
        for _, severity in ipairs(severities) do signs.text[severity] = CODE end
        vim.diagnostic.config({ signs = signs })
        paint()
        -- A colorscheme load clears highlight groups: put the colours back.
        vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = function() paint() end })
    else
        -- Put back only what is still ours. If something replaced it since
        -- (a colorscheme load, lsp.lua's config), that is what should stay.
        local signs = vim.diagnostic.config().signs
        if type(signs) == "table" and signs.text and signs.text[severities[1]] == CODE then
            vim.diagnostic.config({ signs = saved_signs })
        end
        for name, hl in pairs(saved_hl) do
            if ours(name) then vim.api.nvim_set_hl(0, name, hl) end
        end
        saved_signs, saved_hl = nil, {}
    end
end

--- Are the marks on? (for the self-test)
function M.active()
    return on
end

return M
