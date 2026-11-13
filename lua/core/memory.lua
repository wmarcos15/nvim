-- lua/core/memory.lua
--
-- The Orb remembers where you left off in a project. Two plain markdown files
-- live in a hidden folder at the project root:
--
--   <root>/.orb/now.md    a short "where I left off" note
--   <root>/.orb/plan.md   a checklist (Now / Next / Later / Done)
--
-- The note
--   When you quit, the shell tool `orb-note` (~/.config/orb/bin/orb-note) is
--   started in the background and writes now.md from git facts (or a local
--   model). Notes it writes start with a marker line:
--       <!-- orb: written 2025-01-31 18:40 -->
--   The marker means "the Orb wrote this". When YOU save the note, the marker
--   is removed (BufWritePre below), so a note you wrote is never overwritten
--   by a session that never touched it: orb-note is told when this session
--   began (--since) and keeps a hand-written note saved after that.
--
-- The reminder
--   A moment after Neovim starts, the note and the first unchecked plan item
--   are said in the Orb's speech bubble (lua/core/bubble.lua), or through
--   vim.notify when the bubble does not exist. Space o n says it again.
--
-- Keys: Space o n (say it), Space o e (edit the note in a small float),
--       Space o p (the plan panel). Their definitions live in keymaps.lua.
--       Space o s / Space o u (tell the Orb the next step / undo it:
--       lua/core/tell.lua).
--
-- Nothing here ever waits on orb-note: quitting must stay instant.

local M = {}

M.started = os.time() -- the session start, handed to orb-note as --since

-- The plan template. Keep it byte-identical to the one in ~/.config/orb/bin/orb.
M.template = {
    "# Plan", "", "## Now", "", "## Next", "", "## Later", "", "## Done",
}

-- State of this session: which projects had files written, and which notes
-- the user saved by hand. Used to decide what to do on quit.
M.session = { written = {}, hand_saved = {} }

function M.reset_session()
    M.session.written = {}
    M.session.hand_saved = {}
end

-- ── Paths ──────────────────────────────────────────────────────────────

local function real(path)
    local resolved = vim.uv.fs_realpath(path) or path
    return (resolved:gsub("/+$", ""))
end

local function git_root_of(path)
    return vim.fs.root(path, ".git")
end

--- The project root: the git root of `path` (default: the current file, or
--- the working directory), else the working directory.
function M.root(path)
    local from = path
    if not from or from == "" then
        local name = vim.api.nvim_buf_get_name(0)
        if vim.bo.buftype == "" and name ~= "" then
            from = name
        else
            from = vim.fn.getcwd()
        end
    end
    return real(git_root_of(from) or vim.fn.getcwd())
end

function M.paths(root)
    root = root or M.root()
    local dir = root .. "/.orb"
    return { dir = dir, note = dir .. "/now.md", plan = dir .. "/plan.md" }
end

--- The command that writes the note. ORB_NOTE overrides it (used by tests).
function M.note_cmd()
    if vim.env.ORB_NOTE and vim.env.ORB_NOTE ~= "" then return vim.env.ORB_NOTE end
    local config = vim.env.XDG_CONFIG_HOME
    if not config or config == "" then config = vim.env.HOME .. "/.config" end
    return config .. "/orb/bin/orb-note"
end

-- ── Reading ────────────────────────────────────────────────────────────

local MARKER = "^<!%-%- orb: written .-%-%->%s*$"

local function read_lines(path)
    if vim.fn.filereadable(path) ~= 1 then return nil end
    return vim.fn.readfile(path)
end

--- The note as text, without the marker line and without <!-- comments -->.
--- Second result: true when the Orb wrote it (the marker is there).
--- No note, or nothing left after cleaning, gives nil.
function M.read_note(root)
    local lines = read_lines(M.paths(root).note)
    if not lines then return nil, false end
    local by_orb = false
    if lines[1] and lines[1]:match(MARKER) then
        by_orb = true
        table.remove(lines, 1)
    end
    -- Comments can span several lines, so strip them from the joined text.
    local text = table.concat(lines, "\n"):gsub("<!%-%-.-%-%->", "")
    local cleaned = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(cleaned, (line:gsub("%s+$", "")))
    end
    while cleaned[1] == "" do table.remove(cleaned, 1) end
    while cleaned[#cleaned] == "" do table.remove(cleaned) end
    if #cleaned == 0 then return nil, by_orb end
    return table.concat(cleaned, "\n"), by_orb
end

local UNCHECKED = "^%s*[-*+]%s+%[ %]%s+(.-)%s*$"

local function first_unchecked(lines)
    for i, line in ipairs(lines) do
        local item = line:match(UNCHECKED)
        if item then return item, i end
    end
end

--- The first unchecked item of the plan, or nil.
function M.next_item(root)
    local lines = read_lines(M.paths(root).plan)
    if not lines then return nil end
    return (first_unchecked(lines))
end

--- "Last time: <note>" plus "Next: <item>", or nil when there is no note.
function M.reminder(root)
    local note = M.read_note(root)
    if not note then return nil end
    local text = "Last time: " .. note
    local item = M.next_item(root)
    if item then text = text .. "\nNext: " .. item end
    return text
end

-- Close the bubble's reminder (if the bubble exists) before a float opens.
local function clear_bubble()
    local ok, bubble = pcall(require, "core.bubble")
    if ok then pcall(bubble.clear, "memory") end
end

--- Say the reminder. opts.root picks the project; opts.startup means "this
--- is the automatic one": stay silent when there is nothing to say.
--- Returns the text that was said, or nil.
local writing = {} -- root -> true while orb-note is writing its first note

--- Say `text` in the Orb's bubble. `asked` = you asked for it (a key), so if
--- the bubble cannot show (no room, or not the Orb's theme) it becomes an
--- ordinary message; a reminder at start just stays silent then.
local function say(text, asked)
    local ok, bubble = pcall(require, "core.bubble")
    if ok then
        bubble.say(text, nil, { source = "memory", timeout = 12000, until_insert = true, fallback = asked })
        return text
    end
    if not asked then return nil end
    vim.notify(text)
    return text
end
-- tell.lua speaks the result of `orb say` through the same bubble.
M.say = say

function M.remind(opts)
    opts = opts or {}
    local root = opts.root or M.root()
    local text = M.reminder(root)
    -- No note yet: in a git project the Orb writes one now (a few seconds,
    -- in the background) and says it when it is there.
    if not text and not opts.written and not writing[root]
        and vim.uv.fs_stat(root .. "/.git") and vim.fn.executable(M.note_cmd()) == 1 then
        writing[root] = true
        vim.system({ M.note_cmd(), root }, { stdin = false, stdout = false, stderr = false },
            vim.schedule_wrap(function()
                writing[root] = nil
                M.remind(vim.tbl_extend("force", opts, { root = root, written = true }))
            end))
        if not opts.startup then say("One moment: working out where you left off…", true) end
        return nil
    end
    if not text then
        if opts.startup then return nil end
        local item = M.next_item(root)
        if item then
            text = "No note yet.\nNext: " .. item
        else
            text = "No note yet for " .. vim.fs.basename(root) .. ". Space o e writes one."
        end
    end
    return say(text, not opts.startup)
end

-- ── Floats: the note and the plan panel ────────────────────────────────

--- Open `buf` in a floating window described by `config`, with buffer-local
--- keys, and make every way of closing it end in one close() function that
--- saves your edits and removes the keys again (so `x` does not stay mapped
--- in a plan buffer you later open as a normal file).
---   keys: list of { lhs, desc, run = function(win, close), fallback = function() }
---   fallback runs when the key is pressed in another window showing the
---   same buffer; without one, the key does nothing there.
local function open_float(buf, config, keys)
    local previous = vim.api.nvim_get_current_win()
    local win = vim.api.nvim_open_win(buf, true, config)
    local closing = false
    local group = vim.api.nvim_create_augroup("user_orb_memory_float" .. win, { clear = true })

    local function close()
        if closing then return end -- WinLeave, WinClosed and a key can all fire
        closing = true
        -- Edits made in the float are kept. An untouched note is not written,
        -- so the marker stays on a note the Orb wrote.
        if vim.api.nvim_buf_is_valid(buf) then
            pcall(vim.api.nvim_buf_call, buf, function() vim.cmd("silent update") end)
            for _, key in ipairs(keys) do
                pcall(vim.keymap.del, "n", key.lhs, { buffer = buf })
            end
        end
        pcall(vim.api.nvim_del_augroup_by_id, group)
        if vim.api.nvim_win_is_valid(win) then
            pcall(vim.api.nvim_win_close, win, true)
        end
    end

    for _, key in ipairs(keys) do
        vim.keymap.set("n", key.lhs, function()
            if vim.api.nvim_get_current_win() == win then
                key.run(win, close, previous)
            elseif key.fallback then
                key.fallback()
            end
        end, { buffer = buf, silent = true, nowait = true, desc = key.desc })
    end

    vim.api.nvim_create_autocmd("WinLeave", {
        group = group,
        callback = function()
            if vim.api.nvim_get_current_win() == win then
                -- Closing the window we are leaving is not allowed from inside
                -- its own WinLeave, so do it a moment later.
                vim.schedule(close)
            end
        end,
    })
    vim.api.nvim_create_autocmd("WinClosed", {
        group = group,
        callback = function(ev)
            if tonumber(ev.match) == win then close() end
        end,
    })
    return win
end

-- Load a file into a hidden buffer. A buffer left over from an earlier open
-- is refreshed from disk (orb-note may have rewritten the file meanwhile).
local function load_buffer(path)
    local buf = vim.fn.bufadd(path)
    local was_loaded = vim.api.nvim_buf_is_loaded(buf)
    vim.fn.bufload(buf)
    if was_loaded and not vim.bo[buf].modified then
        pcall(vim.api.nvim_buf_call, buf, function() vim.cmd("silent! edit") end)
    end
    if vim.bo[buf].filetype == "" then vim.bo[buf].filetype = "markdown" end
    return buf
end

local function plain_window(win)
    vim.wo[win].wrap = true
    vim.wo[win].linebreak = true
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
end

local function put_cursor(win, buf, lnum)
    lnum = math.max(1, math.min(lnum, vim.api.nvim_buf_line_count(buf)))
    pcall(vim.api.nvim_win_set_cursor, win, { lnum, 0 })
end

--- Edit the note in a small float. The file is not created until you :w.
function M.edit_note(root)
    root = root or M.root()
    clear_bubble()
    local buf = load_buffer(M.paths(root).note)

    local width = math.min(80, math.max(40, math.floor(vim.o.columns * 0.6)))
    local height = 6
    local win = open_float(buf, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2) - 1,
        col = math.floor((vim.o.columns - width) / 2),
        border = "rounded",
        title = " where I left off · " .. vim.fs.basename(root) .. " ",
        title_pos = "center",
        footer = " :w keeps it as yours · q closes ",
        footer_pos = "center",
        zindex = 50,
    }, {
        { lhs = "q", desc = "Close the note", run = function(_, close) close() end },
    })
    plain_window(win)
    local first = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    put_cursor(win, buf, first:match(MARKER) and 2 or 1)
    return win
end

--- Tick or untick the checkbox on line `lnum` (1-based). False: no checkbox.
function M.toggle_checkbox(buf, lnum)
    local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
    if not line then return false end
    local before, mark, after = line:match("^(%s*[-*+]%s+%[)([ xX])(%].*)$")
    if not before then return false end
    local new = (mark == " ") and "x" or " "
    vim.api.nvim_buf_set_lines(buf, lnum - 1, lnum, false, { before .. new .. after })
    return true
end

--- The plan panel: a float showing plan.md (created from the template).
function M.plan(root)
    root = root or M.root()
    clear_bubble()
    local paths = M.paths(root)
    if vim.fn.filereadable(paths.plan) ~= 1 then
        vim.fn.mkdir(paths.dir, "p")
        vim.fn.writefile(M.template, paths.plan)
    end
    local buf = load_buffer(paths.plan)

    local avail = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0)
    local width = math.min(math.max(40, math.floor(vim.o.columns * 0.7)), vim.o.columns - 2)
    local height = math.min(math.max(8, math.floor(avail * 0.7)), avail - 2)
    local win = open_float(buf, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((avail - height) / 2) - 1,
        col = math.floor((vim.o.columns - width) / 2),
        border = "rounded",
        title = " plan · " .. vim.fs.basename(root) .. " ",
        title_pos = "center",
        footer = " x tick · e open in a window · q close ",
        footer_pos = "center",
        zindex = 50,
    }, {
        { lhs = "q", desc = "Close the plan", run = function(_, close) close() end },
        { lhs = "<Esc>", desc = "Close the plan", run = function(_, close) close() end },
        {
            lhs = "x",
            desc = "Tick or untick the item",
            run = function(w)
                M.toggle_checkbox(buf, vim.api.nvim_win_get_cursor(w)[1])
                vim.cmd("silent update")
            end,
            -- Same buffer in another window: x keeps its normal meaning.
            fallback = function() vim.cmd("normal! " .. vim.v.count1 .. "x") end,
        },
        {
            lhs = "e",
            desc = "Open the plan in a normal window",
            run = function(_, close, previous)
                close()
                vim.bo[buf].buflisted = true
                if vim.api.nvim_win_is_valid(previous) then
                    vim.api.nvim_win_set_buf(previous, buf)
                    vim.api.nvim_set_current_win(previous)
                else
                    vim.cmd("buffer " .. buf)
                end
            end,
        },
    })
    plain_window(win)
    vim.wo[win].cursorline = true
    local _, lnum = first_unchecked(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    put_cursor(win, buf, lnum or 1)
    return win, buf
end

-- ── Write on quit ──────────────────────────────────────────────────────

--- Start orb-note for every project written to this session. It runs
--- detached and is never waited for: quitting must not get slower.
--- Returns the roots it started. opts.force runs it even without a UI
--- (headless runs such as `Lazy sync` and the self-test never write notes).
function M.on_quit(opts)
    opts = opts or {}
    local started = {}
    if #vim.api.nvim_list_uis() == 0 and not opts.force then return started end
    local cmd = M.note_cmd()
    if vim.fn.executable(cmd) ~= 1 then return started end

    local roots = vim.tbl_keys(M.session.written)
    table.sort(roots)
    for _, root in ipairs(roots) do
        local info = M.session.written[root]
        local skip = M.session.hand_saved[root]
        -- Outside git, only folders that already opted in with a .orb/ folder:
        -- this keeps ~/.orb from appearing when you edit ~/.zshrc.
        if not info.git then
            local stat = vim.uv.fs_stat(root .. "/.orb")
            if not (stat and stat.type == "directory") then skip = true end
        end
        if not skip then
            local ok = pcall(vim.system, { cmd, "--since", tostring(M.started), root }, {
                detach = true,
                stdin = false,
                stdout = false,
                stderr = false,
            })
            if ok then table.insert(started, root) end
        end
    end
    return started
end

-- ── Autocmds ───────────────────────────────────────────────────────────

local group = vim.api.nvim_create_augroup("user_orb_memory", { clear = true })

-- Saving the note by hand makes it yours: drop the marker line. This works
-- however the file was opened (the float, :edit, or nvim as $EDITOR for
-- `orb now edit`).
vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    pattern = "*/.orb/now.md",
    callback = function(ev)
        local first = vim.api.nvim_buf_get_lines(ev.buf, 0, 1, false)[1]
        if first and first:match(MARKER) then
            vim.api.nvim_buf_set_lines(ev.buf, 0, 1, false, {})
        end
    end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*/.orb/now.md",
    callback = function(ev)
        local file = vim.api.nvim_buf_get_name(ev.buf)
        M.session.hand_saved[real(vim.fn.fnamemodify(file, ":h:h"))] = true
    end,
})

-- Remember which projects had files written (the notes are about them).
vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*",
    callback = function(ev)
        if vim.bo[ev.buf].buftype ~= "" then return end
        local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ev.buf), ":p")
        if path:find("/.git/", 1, true) or path:find("/.orb/", 1, true) then return end
        local root = git_root_of(path)
        if root then
            M.session.written[real(root)] = { time = os.time(), git = true }
            return
        end
        -- Not in git: count it only when the file is under the working
        -- directory, so a stray :w elsewhere does not pick a project.
        local cwd = real(vim.fn.getcwd())
        if real(path):sub(1, #cwd + 1) == cwd .. "/" then
            M.session.written[cwd] = { time = os.time(), git = false }
        end
    end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function() M.on_quit() end,
})

-- The reminder at startup. 300 ms lets themes.lua's 200 ms "marks on" land
-- first, so the bubble's title gets the speaking mark.
vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    callback = function()
        if #vim.api.nvim_list_uis() == 0 or vim.o.diff then return end
        -- A git commit message or `orb now edit`: not a moment for a reminder.
        local first = vim.api.nvim_buf_get_name(0)
        if first:find("/.git/", 1, true) or first:find("/.orb/", 1, true) then return end
        vim.defer_fn(function() M.remind({ startup = true }) end, 300)
    end,
})

-- Keys that only exist inside the float / panel, for the docs page.
local document = require("core.keymaps").document
document("n", "q", { desc = "Close the plan panel (saves your edits)", group = "Orb", where = "in the plan panel" })
document("n", "<Esc>", { desc = "Close the plan panel (saves your edits)", group = "Orb", where = "in the plan panel" })
document("n", "x", { desc = "Tick or untick the plan item", group = "Orb", where = "in the plan panel", tags = "checkbox todo done" })
document("n", "e", { desc = "Open the plan in a normal window", group = "Orb", where = "in the plan panel" })
document("n", "q", { desc = "Close the note (saves your edits)", group = "Orb", where = "in the note float" })

return M
