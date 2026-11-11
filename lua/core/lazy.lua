-- lua/core/lazy.lua

-- Auto-install lazy.nvim if not present
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
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
        colorscheme = { "kanagawa", "habamax" },
    },
    checker = {
        enabled = true, -- check for plugin updates in the background
        notify = false,
    },
    change_detection = {
        notify = false,
    },
    ui = {
        border = "rounded",
    },
})
