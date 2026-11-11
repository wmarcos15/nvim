-- lua/core/orb.lua
--
-- Neovim's side of the Orb, the animated terminal background that lives in
-- ~/.config/orb (its README explains the whole thing, including the shell
-- command `orb`).
--
-- Neovim cannot draw behind its own text, but Ghostty can run a shader over
-- the whole window. A theme slot marked `orb = true` (lua/core/themes.lua)
-- shows the orb; any other slot hides it; quitting hands the terminal back as
-- the shell command left it. The switch is a small file that Ghostty's config
-- includes, plus a reload signal.
--
-- What the orb shows about the editor (mode, errors) travels through the
-- cursor's colour: see lua/core/cursor.lua.
--
-- Needs: Ghostty, the orb project in ~/.config/orb, and its include line in
-- Ghostty's config (`:OrbInfo` prints it). Without any of these, or in another
-- terminal, nothing here runs and the slot uses a solid background.
local M = {}

local config = (vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config")) .. "/orb"
local state = (vim.env.XDG_STATE_HOME or vim.fn.expand("~/.local/state")) .. "/orb"
M.shader = config .. "/orb.glsl"
M.include = state .. "/ghostty.conf" -- the file Ghostty includes
M.pin = state .. "/pin"              -- what `orb on` asked for in a shell
local touched = false -- has this Neovim switched the orb, on or off?

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

--- Can this session show the orb right now?
function M.available()
    return M.in_ghostty() and M.linked() and vim.uv.fs_stat(M.shader) ~= nil
end

-- The Ghostty process this Neovim runs in: walk up the parent chain
-- (nvim <- shell <- login <- ghostty) until a process named ghostty turns up.
local ghostty_pid
local function find_ghostty()
    if ghostty_pid then return ghostty_pid end
    local pid = vim.uv.os_getppid()
    for _ = 1, 12 do
        if not pid or pid <= 1 then break end
        local out = vim.system({ "ps", "-o", "ppid=,comm=", "-p", tostring(pid) }, { text = true }):wait(1000).stdout or ""
        local ppid, comm = out:match("^%s*(%d+)%s+(.-)%s*$")
        if not ppid then break end
        if comm:lower():match("ghostty$") then
            ghostty_pid = pid
            return pid
        end
        pid = tonumber(ppid)
    end
end

-- Ghostty reloads its config on SIGUSR2.
local function reload_ghostty()
    local pid = find_ghostty()
    if pid and vim.uv.kill(pid, "sigusr2") == 0 then return true end
    -- Fallback: every Ghostty. The signal has to be the first argument;
    -- -a because pkill skips its own ancestors.
    return vim.system({ "pkill", "-USR2", "-a", "-x", "ghostty" }):wait(1000).code == 0
end
M.reload_ghostty = reload_ghostty

local function write(lines)
    local ok, old = pcall(vim.fn.readfile, M.include)
    if ok and vim.deep_equal(old, lines) then return end
    vim.fn.mkdir(state, "p")
    vim.fn.writefile(lines, M.include)
    if not reload_ghostty() then
        vim.notify("Orb: could not ask Ghostty to reload its config", vim.log.levels.WARN)
    end
end

--- Show the orb over background colour `bg`. Returns false if it cannot.
function M.show(bg)
    if not M.available() then return false end
    touched = true
    write({
        "# Written by Neovim (lua/core/orb.lua). Do not edit.",
        "background = " .. bg,
        "custom-shader = " .. M.shader,
        "custom-shader-animation = true",
    })
    return true
end

--- Hide the orb (the active theme slot does not use it).
function M.hide()
    if not M.available() then return end
    touched = true
    write({})
end

--- Neovim is quitting: hand the terminal back as the shell left it, which is
--- the pinned orb if `orb on` was used and no orb otherwise.
function M.restore()
    if not (touched and M.available()) then return end
    local ok, pinned = pcall(vim.fn.readfile, M.pin)
    write(ok and pinned or {})
end

vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("user_orb", { clear = true }),
    callback = M.restore,
})

vim.api.nvim_create_user_command("OrbInfo", function()
    print(table.concat({
        "Terminal:            " .. (vim.env.TERM_PROGRAM or "unknown"),
        "Orb project:         " .. (vim.uv.fs_stat(M.shader) and config or ("not found at " .. config)),
        "Ghostty include:     config-file = ?" .. M.include,
        "Included by Ghostty: " .. tostring(M.linked()),
        "Orb:                 " .. (M.available() and "available" or "not available here (solid background is used)"),
        "Pinned from a shell: " .. (vim.uv.fs_stat(M.pin) and "yes (comes back when Neovim quits; `orb off` to release)" or "no"),
        "Ghostty process:     " .. tostring(find_ghostty() or "not found among this Neovim's parents"),
    }, "\n"))
end, { desc = "Show whether the Orb background can run in this terminal" })

return M
