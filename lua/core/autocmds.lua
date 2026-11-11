-- lua/core/autocmds.lua
local function augroup(name)
    return vim.api.nvim_create_augroup("user_" .. name, { clear = true })
end
local autocmd = vim.api.nvim_create_autocmd

-- Flash the text you just yanked
autocmd("TextYankPost", {
    group = augroup("highlight_yank"),
    callback = function() vim.hl.on_yank({ timeout = 150 }) end,
})

-- Reopen files at the last cursor position
autocmd("BufReadPost", {
    group = augroup("last_location"),
    callback = function(ev)
        if vim.bo[ev.buf].filetype == "gitcommit" then return end
        local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
        if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})

-- :w into a folder that does not exist yet creates it
autocmd("BufWritePre", {
    group = augroup("auto_create_dir"),
    callback = function(ev)
        if ev.match:match("^%w%w+:[\\/][\\/]") then return end
        local file = vim.uv.fs_realpath(ev.match) or ev.match
        vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
    end,
})

-- Pick up files changed outside Neovim
autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
    group = augroup("checktime"),
    callback = function()
        if vim.o.buftype ~= "nofile" then vim.cmd("checktime") end
    end,
})

-- q closes throwaway windows
autocmd("FileType", {
    group = augroup("close_with_q"),
    pattern = { "help", "qf", "man", "checkhealth", "lspinfo", "notify", "startuptime" },
    callback = function(ev)
        vim.bo[ev.buf].buflisted = false
        vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true, desc = "Close window" })
    end,
})

-- Terminals opened by <leader>rb / <leader>rr: no line numbers, start typing
autocmd("TermOpen", {
    group = augroup("terminal"),
    callback = function()
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
        vim.opt_local.signcolumn = "no"
    end,
})
