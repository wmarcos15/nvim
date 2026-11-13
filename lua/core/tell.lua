-- lua/core/tell.lua
--
-- Tell the Orb the next step: Neovim's side of `orb say` (~/.config/orb/bin/orb-say).
-- Space o s asks for one sentence ("Tell the Orb: "); the program decides whether it
-- adds, ticks, moves or drops one plan item, edits .orb/plan.md itself and answers in
-- one line, which the Orb says in its bubble. Space o u undoes the Orb's last change.
-- While the program works the cursor shows the working state (violet). All plan logic
-- lives in orb-say; this file only asks, waits, reloads the plan and speaks.
-- Nothing here blocks: the program runs through vim.system.

local M = {}

local running = {} -- root -> true while orb-say works for that project

--- The command. ORB_SAY overrides it (used by tests), as ORB_NOTE does for orb-note.
function M.cmd()
    if vim.env.ORB_SAY and vim.env.ORB_SAY ~= "" then return vim.env.ORB_SAY end
    local config = vim.env.XDG_CONFIG_HOME
    if not config or config == "" then config = vim.env.HOME .. "/.config" end
    return config .. "/orb/bin/orb-say"
end

-- Say it through memory.lua, looked up at call time so tests can replace it.
local function speak(text)
    require("core.memory").say(text, true)
end

local function same_file(name, path)
    return name ~= "" and (vim.uv.fs_realpath(name) or name) == (vim.uv.fs_realpath(path) or path)
end

-- Loaded buffers that show the plan file.
local function plan_buffers(path)
    local found = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and same_file(vim.api.nvim_buf_get_name(buf), path) then
            table.insert(found, buf)
        end
    end
    return found
end

-- Re-read the plan in every buffer that has it. A buffer with unsaved edits is
-- left alone (reloading would lose them); the result says so. Returns true if
-- one was skipped.
local function reload(path)
    local skipped = false
    for _, buf in ipairs(plan_buffers(path)) do
        if vim.bo[buf].modified then
            skipped = true
        else
            pcall(vim.api.nvim_buf_call, buf, function() vim.cmd("silent! edit") end)
        end
    end
    return skipped
end

-- The text to say for a finished run: orb-say's own line when it gave one.
local function message(res, skipped)
    local last
    for line in (res.stdout or ""):gmatch("[^\n]+") do
        if line:match("%S") then last = line end
    end
    if last then
        local ok, obj = pcall(vim.json.decode, last)
        if ok and type(obj) == "table" and type(obj.line) == "string" and obj.line ~= "" then
            if obj.changed == true and skipped then
                return obj.line .. "\n(The plan has unsaved edits here, so it was not reloaded.)"
            end
            return obj.line
        end
    end
    if res.code == 124 then return "The Orb took too long. Nothing was said back." end
    -- Not the word "error": the self-test scans :messages for it.
    local first = (res.stderr or ""):match("[^\n]+")
    local why = first and first:gsub("^orb%-say: ", "") or ("exit " .. tostring(res.code))
    return "The Orb could not do that: " .. why
end

-- Run orb-say with `argv_tail` for `root`. Returns false when it did not start.
local function run(root, argv_tail)
    if running[root] then
        speak("One moment: the Orb is still on the last one.")
        return false
    end
    local path = require("core.memory").paths(root).plan
    for _, buf in ipairs(plan_buffers(path)) do
        if vim.bo[buf].modified then
            speak("The plan has unsaved changes: save it first. Nothing changed.")
            return false
        end
    end
    local cmd = M.cmd()
    if vim.fn.executable(cmd) ~= 1 then
        speak("orb say is not installed (" .. cmd .. ").")
        return false
    end

    local cursor = require("core.cursor")
    local busy_name = "orb-say:" .. root
    local argv = { cmd, "--json" }
    vim.list_extend(argv, argv_tail)

    local function finish(res)
        running[root] = nil
        cursor.busy(busy_name, false)
        -- Reload after every exit: the plan may have changed whatever the result.
        local skipped = reload(path)
        speak(message(res, skipped))
    end

    running[root] = true
    cursor.busy(busy_name, true)
    vim.api.nvim_echo({ { "Telling the Orb…" } }, false, {})
    local ok = pcall(vim.system, argv, { text = true, stdin = false, timeout = 180000 }, vim.schedule_wrap(finish))
    if not ok then
        running[root] = nil
        cursor.busy(busy_name, false)
        speak("The Orb could not do that: it did not start.")
        return false
    end
    return true
end

--- Tell the Orb one sentence about the plan. opts.root picks the project.
function M.tell(text, opts)
    opts = opts or {}
    text = vim.trim(text or "")
    if text == "" then return false end
    local root = opts.root or require("core.memory").root()
    return run(root, { "--", root, text })
end

--- Put the plan back as it was before the Orb's last change.
function M.undo(opts)
    opts = opts or {}
    local root = opts.root or require("core.memory").root()
    return run(root, { "--undo", "--", root })
end

--- Ask for the sentence, then tell it.
function M.prompt(opts)
    vim.ui.input({ prompt = "Tell the Orb: " }, function(input)
        if input and vim.trim(input) ~= "" then M.tell(input, opts) end
    end)
end

return M
