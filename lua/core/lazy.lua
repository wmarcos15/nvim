-- lua/core/lazy.lua

-- Auto-install lazy.nvim if not present
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    spec = {
        { import = "plugins" }, -- auto-imports everything in lua/plugins/
    },
    defaults = {
        lazy = false,
    },
    install = {
        colorscheme = { "kanagawa", "habamax" }, -- fallback if kanagawa not yet installed
    },
    checker = {
        enabled = true,   -- auto-check for plugin updates
        notify = false,   -- but don't spam notifications
    },
    change_detection = {
        notify = false,   -- don't notify on config change
    },
    ui = {
        border = "rounded",
    },
})
