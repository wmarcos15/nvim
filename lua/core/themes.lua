-- lua/core/themes.lua
--
-- THEME SLOTS. Slot N is on <leader>tN. <leader>tn cycles, <leader>tt browses
-- every installed colorscheme in Telescope. The last choice is remembered.
--
-- ── Adding or changing a theme ─────────────────────────────────────────
-- 1. If it comes from a new plugin, add the plugin to lua/plugins/ui.lua
--    with `lazy = true` (it then only loads when its slot is used).
-- 2. Add or edit an entry in M.slots below. Fields:
--
--      name         shown when you switch, and in the keymap docs
--      colorscheme  what you would type after :colorscheme
--      setup        optional function(ctx), runs before the colorscheme is
--                   applied; put the plugin's setup({...}) call here
--      shader       optional file in shaders/: an animated background, shown
--                   when running in Ghostty (lua/core/terminal.lua). setup
--                   and highlights get ctx.animated = true when it is active,
--                   so the theme can go transparent only then
--      highlights   optional function(ctx) returning { Group = { fg=, bg=, ... } }
--                   overrides, applied after the colorscheme
--      statusline   "classic" | "slant" | "minimal" | "hud"   (see M.statuslines)
--      docs         optional colours for the keymap docs page, e.g.
--                   { bg = "#101014" }. Anything left out is read from the
--                   colorscheme itself. Transparent themes need `bg`.
--
-- A 4th, 5th, ... entry gets <leader>t4, <leader>t5, ... automatically.
local M = {}

local function kanagawa(variant)
    return function()
        require("kanagawa").setup({
            compile = false,
            undercurl = true,
            transparent = true, -- terminal background shows through
            terminalColors = true,
            dimInactive = false,
            theme = variant,
            background = { dark = variant, light = "lotus" },
            colors = { theme = { all = { ui = { bg_gutter = "none" } } } },
            overrides = function(colors)
                local theme = colors.theme
                return {
                    -- Floating windows transparent too
                    NormalFloat = { bg = "none" },
                    FloatBorder = { bg = "none" },
                    FloatTitle  = { bg = "none" },

                    TelescopeNormal        = { bg = "none" },
                    TelescopeBorder        = { bg = "none" },
                    TelescopeResultsNormal = { bg = "none" },
                    TelescopePreviewNormal = { bg = "none" },
                    TelescopePromptNormal  = { bg = "none" },

                    -- Completion menu
                    Pmenu    = { fg = theme.ui.shade0, bg = "none" },
                    PmenuSel = { bg = theme.ui.bg_p2 },

                    Visual = { bg = theme.ui.bg_p2 },
                }
            end,
        })
    end
end

M.slots = {
    -- 1 ── the original look
    {
        name = "Kanagawa Wave",
        colorscheme = "kanagawa-wave",
        setup = kanagawa("wave"),
        statusline = "classic",
        docs = { bg = "#1F1F28" },
    },

    -- 2 ── control centre: Cyberdream's neon on near-black, with the interface
    --      chrome reduced to thin cyan lines: outlined panels for pickers and
    --      floats, a flat statusline, dim rulers.
    --      In Ghostty (once linked, see lua/core/terminal.lua) the background is
    --      the animated shaders/hud.glsl; anywhere else it is solid.
    --      (shaders/cyber-grid.glsl is an alternative: a neon grid corridor.)
    {
        name = "Cyberdream HUD",
        colorscheme = "cyberdream",
        shader = "hud.glsl",
        setup = function(ctx)
            require("cyberdream").setup({
                transparent = ctx.animated, -- see-through only when there is something to see
                italic_comments = true,
                borderless_pickers = false, -- panels get a thin outline instead
                terminal_colors = true,
            })
        end,
        highlights = function(ctx)
            local cyan, line, dim = "#5ef1ff", "#2a6f7a", "#3c4048"
            local panel = ctx.animated and "none" or "#16181a"
            return {
                -- rulers
                CursorLineNr = { fg = cyan, bold = true },
                LineNr       = { fg = dim },
                WinSeparator = { fg = line },
                -- panels: floats, pickers, completion and hover windows
                NormalFloat  = { bg = panel },
                FloatBorder  = { fg = line, bg = panel },
                FloatTitle   = { fg = cyan, bg = panel, bold = true },
                TelescopeNormal        = { bg = panel },
                TelescopeBorder        = { fg = line, bg = panel },
                TelescopePromptBorder  = { fg = cyan, bg = panel },
                TelescopeTitle         = { fg = cyan, bg = panel, bold = true },
                TelescopePromptTitle   = { fg = cyan, bg = panel, bold = true },
                TelescopeResultsTitle  = { fg = cyan, bg = panel, bold = true },
                TelescopePreviewTitle  = { fg = cyan, bg = panel, bold = true },
                TelescopePromptPrefix  = { fg = cyan },
                TelescopeSelectionCaret = { fg = cyan },
                TelescopeMatching      = { fg = cyan, bold = true },
                PmenuSel     = { fg = "#16181a", bg = cyan, bold = true },
                LspInlayHint = { fg = "#7b8496", italic = true },
            }
        end,
        statusline = "hud",
        docs = { bg = "#16181a", accent = "#5ef1ff", accent2 = "#ffbd5e" },
    },

    -- 3 ── mainstream and calm: VS Code's default dark theme, solid background
    {
        name = "VS Code Dark",
        colorscheme = "vscode",
        setup = function()
            vim.o.background = "dark"
            require("vscode").setup({ transparent = false, italic_comments = true })
        end,
        statusline = "classic",
    },
}

-- Statusline shapes a slot can pick from (needs a Nerd Font for "slant").
M.statuslines = {
    classic = { component = "|", section = { left = "", right = "" } },
    slant   = { component = { left = "\u{e0bb}", right = "\u{e0bb}" }, section = { left = "\u{e0bc}", right = "\u{e0ba}" } },
    minimal = { component = "", section = { left = "", right = "" } },
    hud     = { component = "\u{2502}", section = { left = "", right = "" }, upper = true },
}

-- ── Implementation ─────────────────────────────────────────────────────
local state_file = vim.fn.stdpath("state") .. "/theme"
local applying = false
M.current = nil

local function save(line)
    pcall(vim.fn.writefile, { line }, state_file)
end

--- (Re)build the statusline in the current slot's shape.
function M.statusline()
    local ok, lualine = pcall(require, "lualine")
    if not ok then return end
    local slot = M.slots[M.current] or {}
    local shape = M.statuslines[slot.statusline or "classic"] or M.statuslines.classic
    lualine.setup({
        options = {
            theme = "auto", -- follows the active colorscheme
            globalstatus = true,
            component_separators = shape.component,
            section_separators = shape.section,
        },
        sections = {
            -- "hud" shows the mode as a bracketed readout: [ NORMAL ]
            lualine_a = { { "mode", fmt = shape.upper and function(m) return "[ " .. m .. " ]" end or nil } },
            lualine_b = { "branch", "diff", "diagnostics" },
            lualine_c = { { "filename", path = 1 } },
            lualine_x = { "encoding", "filetype" },
            lualine_y = { "progress" },
            lualine_z = { "location" },
        },
    })
end

local function activate(slot)
    applying = true
    -- ctx.animated: this slot has a shader and the terminal can run it
    local ctx = { animated = slot.shader ~= nil and require("core.terminal").can_animate() }
    local ok, err = pcall(function()
        if slot.setup then slot.setup(ctx) end
        vim.cmd.colorscheme(slot.colorscheme)
        if slot.highlights then
            for group, hl in pairs(slot.highlights(ctx)) do
                vim.api.nvim_set_hl(0, group, hl)
            end
        end
    end)
    applying = false
    return ok, err
end

--- Switch to slot `i`.
function M.apply(i, opts)
    opts = opts or {}
    local slot = M.slots[i]
    if not slot then
        vim.notify(("Theme slot %d is empty. Add it in lua/core/themes.lua"):format(i), vim.log.levels.WARN)
        return false
    end
    local ok, err = activate(slot)
    if not ok then
        vim.notify(("Theme %d (%s) failed: %s"):format(i, slot.name, err), vim.log.levels.ERROR)
        return false
    end
    M.current = i
    M.current_colors_name = vim.g.colors_name
    M.statusline()
    local terminal = require("core.terminal")
    if not (slot.shader and terminal.animate(slot.shader, (slot.docs or {}).bg or "#000000")) then
        terminal.reset()
    end
    if not opts.temporary then save("slot=" .. i) end
    if not opts.silent then vim.notify(("Theme %d: %s"):format(i, slot.name)) end
    return true
end

--- Cycle to the next slot.
function M.next()
    M.apply(((M.current or 0) % #M.slots) + 1)
end

--- Apply whatever was active last time (called from init.lua).
function M.load()
    local ok, lines = pcall(vim.fn.readfile, state_file)
    local saved = ok and lines[1] or ""
    local slot = tonumber(saved:match("^slot=(%d+)$"))
    local name = saved:match("^colorscheme=(.+)$")
    if slot and M.apply(slot, { silent = true }) then return end
    if name and pcall(vim.cmd.colorscheme, name) then return end
    if not M.apply(1, { silent = true }) then pcall(vim.cmd.colorscheme, "habamax") end
end

-- A colorscheme picked outside the slots (<leader>tt, :colorscheme) is remembered too.
vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("user_theme_persist", { clear = true }),
    callback = function(ev)
        if applying then return end
        -- Neovim re-runs the current colorscheme by itself when it detects the
        -- terminal's light/dark background at startup. That is still the same
        -- slot: keep it, and put the slot's own highlights back.
        local slot = M.slots[M.current]
        if slot and ev.match == M.current_colors_name then
            if slot.highlights then
                local ctx = { animated = slot.shader ~= nil and require("core.terminal").can_animate() }
                for group, hl in pairs(slot.highlights(ctx)) do
                    vim.api.nvim_set_hl(0, group, hl)
                end
            end
            return
        end
        M.current = nil
        save("colorscheme=" .. ev.match)
    end,
})

--- Colours of every slot, for the keymap docs page.
function M.palettes()
    local function hex(group, attr)
        local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
        return hl[attr] and ("#%06x"):format(hl[attr]) or nil
    end
    local previous, previous_name = M.current, vim.g.colors_name
    local out = {}
    for i, slot in ipairs(M.slots) do
        if activate(slot) then
            out[i] = vim.tbl_extend("force", {
                name = slot.name,
                bg = hex("Normal", "bg") or "#14141a",
                fg = hex("Normal", "fg") or "#d8d8e0",
                muted = hex("Comment", "fg") or "#7a7a8a",
                accent = hex("Function", "fg") or "#7aa2f7",
                accent2 = hex("Keyword", "fg") or "#bb9af7",
                string = hex("String", "fg") or "#9ece6a",
                warn = hex("DiagnosticWarn", "fg") or "#e0af68",
            }, slot.docs or {})
        end
    end
    if previous then
        M.apply(previous, { silent = true, temporary = true })
    elseif previous_name then
        applying = true
        pcall(vim.cmd.colorscheme, previous_name)
        applying = false
    end
    return out
end

return M
