-- Load order matters:
--   options   plain editor settings
--   keymaps   sets <leader> (must happen before lazy.nvim loads plugins)
--   lazy      plugin manager + everything in lua/plugins/
--   autocmds  small quality-of-life automations
--   docs      the :KeymapDocs command
--   start     the start screen shown when no file was given
--   themes    applies the theme slot you used last
require("core.options")
require("core.keymaps")
require("core.lazy")
require("core.autocmds")
require("core.docs") -- :KeymapDocs
require("core.start")
require("core.themes").load()
