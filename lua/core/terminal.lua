-- lua/core/terminal.lua
--
-- Animated terminal background for theme slots that name a `shader`.
--
-- Neovim cannot draw behind its own text, but Ghostty can: it runs a custom
-- shader over the whole window. So when such a slot is applied inside Ghostty,
-- this module writes a tiny Ghostty config file that turns the shader on, and
-- asks Ghostty to reload (it reloads on SIGUSR2). Leaving the slot, or
-- quitting Neovim, turns it off again.
--
-- One-time setup: Ghostty has to include that file. Add this line to Ghostty's
-- config (~/Library/Application Support/com.mitchellh.ghostty/config):
--
--     config-file = ?<the path printed by :ThemeTerminalInfo>
--
-- Without that line, or in any other terminal (iTerm, ...), nothing here runs
-- and the slot falls back to a solid background.
local M = {}

M.include = vim.fn.stdpath("state") .. "/ghostty-theme.conf"
local shader_dir = vim.fn.stdpath("config") .. "/shaders/"
local owned = false -- did this Neovim turn the shader on?

local function ghostty_configs()
    local xdg = vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config")
    return {
        vim.fn.expand("~/Library/Application Support/com.mitchellh.ghostty/config"),
        xdg .. "/ghostty/config",
    }
end

function M.in_ghostty()
    return vim.env.TERM_PROGRAM == "ghostty" and not vim.env.TMUX and not vim.tbl_contains(vim.v.argv, "--headless")
end

local linked
function M.linked()
    if linked == nil then
        linked = false
        for _, path in ipairs(ghostty_configs()) do
            local ok, lines = pcall(vim.fn.readfile, path)
            if ok and table.concat(lines, "\n"):find(M.include, 1, true) then linked = true end
        end
    end
    return linked
end

--- Can this session show an animated background right now?
function M.can_animate()
    return M.in_ghostty() and M.linked()
end

local function write(lines, wait)
    local ok, old = pcall(vim.fn.readfile, M.include)
    if ok and vim.deep_equal(old, lines) then return end
    vim.fn.writefile(lines, M.include)
    -- -a: pkill skips its own ancestors by default, and Ghostty is one (it
    -- started the shell that started this Neovim).
    local job = vim.system({ "pkill", "-a", "-USR2", "-x", "ghostty" })
    if wait then job:wait(1000) end
end

--- Turn on `shader` (a file in shaders/) over background colour `bg`.
function M.animate(shader, bg)
    if not M.can_animate() then return false end
    owned = true
    write({
        "# Written by Neovim (lua/core/terminal.lua). Do not edit.",
        "background = " .. bg,
        "custom-shader = " .. shader_dir .. shader,
        "custom-shader-animation = true",
    })
    return true
end

--- Turn the shader off.
function M.reset(wait)
    if not M.can_animate() then return end
    owned = false
    write({}, wait)
end

vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("user_terminal_bg", { clear = true }),
    callback = function() if owned then M.reset(true) end end,
})

vim.api.nvim_create_user_command("ThemeTerminalInfo", function()
    print(table.concat({
        "Terminal:            " .. (vim.env.TERM_PROGRAM or "unknown"),
        "Ghostty include:     config-file = ?" .. M.include,
        "Included by Ghostty: " .. tostring(M.linked()),
        "Animated background: " .. (M.can_animate() and "available" or "not available here (solid background is used)"),
    }, "\n"))
end, { desc = "Show whether the animated theme background can run in this terminal" })

return M
