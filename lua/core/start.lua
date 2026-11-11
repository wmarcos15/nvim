-- lua/core/start.lua
--
-- The start screen: what you see when Neovim opens without a file. Recent
-- files (press their number, or Enter on the line) and a few reminders of
-- where things are. It is an ordinary scratch buffer: every normal key works,
-- and it disappears as soon as you open something.
--
-- The key reminders are read from the keymap registry (lua/core/keymaps.lua),
-- so they always show the real bindings.
local M = {}

local MAX_RECENT = 8
local MARGIN = 6
-- Which keymaps to remind of, in this order (skipped if one no longer exists).
local hints = { "<leader>ff", "<leader>fg", "<leader>fr", "<leader>e", "<leader>?", "<leader>q" }

--- "<leader>ff" -> "Space f f"
local function pretty(lhs)
    local rest = lhs:gsub("^<leader>", "")
    if rest == lhs then return lhs end
    return "Space " .. rest:gsub(".", "%0 "):gsub(" $", "")
end

--- Recently opened files that still exist: this project's first.
function M.recent()
    local cwd = vim.fn.getcwd() .. "/"
    local here, elsewhere, seen = {}, {}, {}
    for _, path in ipairs(vim.v.oldfiles) do
        if not seen[path] and not path:find("/.git/", 1, true) and not path:match("^%w+://")
            and vim.fn.filereadable(path) == 1 then
            seen[path] = true
            table.insert(vim.startswith(path, cwd) and here or elsewhere, path)
        end
    end
    local out = {}
    for _, list in ipairs({ here, elsewhere }) do
        for _, path in ipairs(list) do
            if #out < MAX_RECENT then table.insert(out, path) end
        end
    end
    return out
end

--- Should the start screen replace the empty buffer Neovim opened with?
function M.wanted()
    return vim.fn.argc() == 0
        and not M.stdin
        and vim.api.nvim_buf_get_name(0) == ""
        and vim.bo.buftype == ""
        and vim.api.nvim_buf_line_count(0) == 1
        and vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == ""
end

--- Show the start screen in the current window. Returns its buffer.
function M.open()
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_get_current_win()
    local pad = (" "):rep(MARGIN)
    local lines, marks, files = {}, {}, {}

    local function add(text, ...)
        table.insert(lines, text == "" and "" or pad .. text)
        for _, m in ipairs({ ... }) do -- { from, to, group }, columns within `text`
            table.insert(marks, { #lines - 1, MARGIN + m[1], MARGIN + m[2], m[3] })
        end
    end

    for _ = 1, math.max(1, math.floor(vim.api.nvim_win_get_height(win) / 5)) do add("") end
    local title = "NEOVIM " .. tostring(vim.version())
    local where = vim.fn.fnamemodify(vim.fn.getcwd(), ":~")
    add(title .. "  ·  " .. where, { 0, #title, "Title" }, { #title, #title + #where + 5, "Comment" })
    add("")

    local recent = M.recent()
    if #recent > 0 then
        add("RECENT", { 0, 6, "Comment" })
        for i, path in ipairs(recent) do
            local shown = vim.fn.fnamemodify(path, ":~:.")
            local dir = shown:match("^(.*/)") or ""
            add(i .. "  " .. shown, { 0, 1, "CursorLineNr" }, { 3, 3 + #dir, "Comment" })
            files[#lines] = path
        end
        add("")
    end

    local registry = {}
    for _, entry in ipairs(require("core.keymaps").registry) do registry[entry.keys] = entry end
    local width = 0
    for _, lhs in ipairs(hints) do width = math.max(width, #pretty(lhs)) end
    for _, lhs in ipairs(hints) do
        local entry = registry[lhs]
        if entry then
            local keys = pretty(lhs)
            add(keys .. (" "):rep(width - #keys + 3) .. entry.desc, { 0, #keys, "Special" })
        end
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    local ns = vim.api.nvim_create_namespace("user_start")
    for _, m in ipairs(marks) do
        vim.api.nvim_buf_set_extmark(buf, ns, m[1], m[2], { end_col = math.min(m[3], #lines[m[1] + 1]), hl_group = m[4] })
    end
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "start"

    -- A plain page: no line numbers or signs while it is shown.
    local plain = { number = false, relativenumber = false, signcolumn = "no", cursorline = false, list = false }
    local before = {}
    for name in pairs(plain) do before[name] = vim.wo[win][name] end
    vim.api.nvim_win_set_buf(win, buf)
    for name, value in pairs(plain) do vim.wo[win][name] = value end
    vim.api.nvim_create_autocmd("BufWinLeave", {
        buffer = buf,
        once = true,
        callback = function()
            if not vim.api.nvim_win_is_valid(win) then return end
            for name, value in pairs(before) do vim.wo[win][name] = value end
        end,
    })

    local function edit(path)
        return function() vim.cmd.edit(vim.fn.fnameescape(path)) end
    end
    for i, path in ipairs(recent) do
        vim.keymap.set("n", tostring(i), edit(path), { buffer = buf, nowait = true, desc = "Open recent file " .. i })
    end
    vim.keymap.set("n", "<CR>", function()
        local path = files[vim.api.nvim_win_get_cursor(0)[1]]
        if path then edit(path)() end
    end, { buffer = buf, desc = "Open the recent file on this line" })

    local first = next(files) and math.min(unpack(vim.tbl_keys(files))) or 1
    vim.api.nvim_win_set_cursor(win, { first, MARGIN })
    return buf
end

local document = require("core.keymaps").document
document("n", "1 … 8", { desc = "Open that recent file", group = "Files", where = "on the start screen", tags = "dashboard home welcome" })
document("n", "<CR>", { desc = "Open the recent file on this line", group = "Files", where = "on the start screen", tags = "dashboard home welcome" })

local group = vim.api.nvim_create_augroup("user_start", { clear = true })
vim.api.nvim_create_autocmd("StdinReadPre", { group = group, callback = function() M.stdin = true end })
vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    nested = true,
    callback = function()
        if M.wanted() then M.open() end
    end,
})

return M
