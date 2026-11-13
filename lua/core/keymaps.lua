-- lua/core/keymaps.lua
--
-- Every keymap this config defines goes through map() below, which also
-- records it in M.registry. The keymap docs (:KeymapDocs) are generated from
-- that registry, so the docs can never drift from what is actually bound.
--
-- Extra fields accepted in opts (stripped before vim.keymap.set):
--   group  section in the docs ("Find", "LSP", "Git", ...)
--   tags   extra search words for the docs ("how do I ..." phrasing)
--   lang   language this map only exists for ("C/C++", ...)
--
-- Leader groups (no key is a prefix of another, so nothing waits on timeoutlen):
--   <leader>f  find (Telescope)      <leader>c  code
--   <leader>g  git hunks             <leader>d  debug
--   <leader>r  run / build           <leader>t  toggles + themes
--   <leader>s  swap arguments        <leader>h  harpoon next / previous
--   <leader>o  orb (note, plan, tell, undo)

local M = { registry = {} }
local seen = {}

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local function record(mode, lhs, opts)
    local modes = type(mode) == "table" and mode or { mode }
    local id = table.concat(modes, "") .. " " .. lhs .. " " .. (opts.where or "")
    if seen[id] then return end
    seen[id] = true
    table.insert(M.registry, {
        keys = lhs,
        modes = modes,
        desc = opts.desc,
        group = opts.group or "General",
        tags = opts.tags,
        lang = opts.lang,
        where = opts.where, -- e.g. "inside a Telescope picker"
        recorded = opts.recorded, -- came from M.document()
    })
end

--- Define a keymap and record it for the docs.
function M.map(mode, lhs, rhs, opts)
    opts = vim.deepcopy(opts or {})
    record(mode, lhs, opts)
    opts.group, opts.tags, opts.lang, opts.where = nil, nil, nil, nil
    if opts.silent == nil then opts.silent = true end
    vim.keymap.set(mode, lhs, rhs, opts)
end

--- Record a keymap that a plugin's own config table defines (treesitter text
--- objects, completion menu keys, ...), so it shows up in the docs too.
function M.document(mode, lhs, opts)
    opts = vim.deepcopy(opts)
    opts.recorded = true
    record(mode, lhs, opts)
end

local map = M.map

-- Call a Telescope builtin picker without loading Telescope at startup.
local function tele(picker, picker_opts)
    return function() require("telescope.builtin")[picker](picker_opts) end
end

map("n", "<Space>", "<Nop>", { desc = "Leader key (does nothing on its own)", group = "General" })
map("n", "Q", "<Nop>", { desc = "Disabled (no accidental Ex mode)", group = "General" })

-- ── Windows ────────────────────────────────────────────────────────────
map("n", "<C-h>", "<C-w>h", { desc = "Focus window to the left", group = "Windows", tags = "move split pane" })
map("n", "<C-j>", "<C-w>j", { desc = "Focus window below", group = "Windows", tags = "move split pane" })
map("n", "<C-k>", "<C-w>k", { desc = "Focus window above", group = "Windows", tags = "move split pane" })
map("n", "<C-l>", "<C-w>l", { desc = "Focus window to the right", group = "Windows", tags = "move split pane" })
map("n", "<leader>v", "<cmd>vsplit<cr>", { desc = "Split window vertically", group = "Windows", tags = "side by side" })
map("n", "<leader>-", "<cmd>split<cr>", { desc = "Split window horizontally", group = "Windows", tags = "stacked" })

-- ── Files ──────────────────────────────────────────────────────────────
map("n", "<leader>w", "<cmd>write<cr>", { desc = "Save file", group = "Files", tags = "write" })
map("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit window", group = "Files", tags = "close exit" })
map("n", "<leader>e", "<cmd>Explore<cr>", { desc = "File explorer (netrw) in this file's folder", group = "Files", tags = "browse directory tree" })
map("n", "<leader>x", "<cmd>!chmod +x %<cr>", { desc = "Make current file executable", group = "Files", tags = "chmod script" })
map("n", "<leader>?", "<cmd>KeymapDocs<cr>", { desc = "Open keymap docs in the browser", group = "General", tags = "help cheatsheet shortcuts" })
map("n", "<leader>u", "<cmd>UndotreeToggle<cr>", { desc = "Undo history tree", group = "Files", tags = "undotree revert time travel" })

-- ── Movement ───────────────────────────────────────────────────────────
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down, cursor centred", group = "Movement", tags = "scroll" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up, cursor centred", group = "Movement", tags = "scroll" })
map("n", "n", "nzzzv", { desc = "Next search match, centred", group = "Movement" })
map("n", "N", "Nzzzv", { desc = "Previous search match, centred", group = "Movement" })
map("n", "J", "mzJ`z", { desc = "Join line below, cursor stays put", group = "Editing" })

-- ── Editing ────────────────────────────────────────────────────────────
map("x", "<", "<gv", { desc = "Indent left, keep selection", group = "Editing" })
map("x", ">", ">gv", { desc = "Indent right, keep selection", group = "Editing" })
map("x", "J", ":m '>+1<cr>gv=gv", { desc = "Move selected lines down", group = "Editing" })
map("x", "K", ":m '<-2<cr>gv=gv", { desc = "Move selected lines up", group = "Editing" })
map({ "n", "x" }, "<leader>y", [["+y]], { desc = "Yank to system clipboard", group = "Editing", tags = "copy" })
map("n", "<leader>Y", [["+Y]], { desc = "Yank line to system clipboard", group = "Editing", tags = "copy" })
map("x", "<leader>p", [["_dP]], { desc = "Paste over selection, keep what you yanked", group = "Editing", tags = "replace register" })

-- ── Find (Telescope) ───────────────────────────────────────────────────
map("n", "<leader>ff", tele("find_files"), { desc = "Find files", group = "Find", tags = "open file fuzzy search" })
map("n", "<leader>fg", tele("live_grep"), { desc = "Search text in project (live grep)", group = "Find", tags = "ripgrep rg search string" })
map("n", "<leader>fw", tele("grep_string"), { desc = "Search project for word under cursor", group = "Find", tags = "grep usages" })
map("n", "<leader>fb", tele("buffers"), { desc = "Find open buffers", group = "Find", tags = "switch file tabs" })
map("n", "<leader>fr", tele("oldfiles"), { desc = "Recent files", group = "Find", tags = "history" })
map("n", "<leader>fd", tele("diagnostics"), { desc = "List diagnostics (errors, warnings, lint)", group = "Find", tags = "problems linter" })
map("n", "<leader>fs", tele("lsp_dynamic_workspace_symbols"), { desc = "Find symbol in project", group = "Find", tags = "function class workspace symbols" })
map("n", "<leader>fk", tele("keymaps"), { desc = "Search keymaps", group = "Find", tags = "shortcuts help" })
map("n", "<leader>fl", tele("resume"), { desc = "Reopen last picker", group = "Find", tags = "resume" })
map("n", "<leader>fn", function()
    require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "Find Neovim config files", group = "Find", tags = "dotfiles settings" })
map("n", "<leader>/", tele("current_buffer_fuzzy_find"), { desc = "Fuzzy search in current buffer", group = "Find", tags = "lines" })

-- ── Harpoon ────────────────────────────────────────────────────────────
map("n", "<leader>a", function() require("harpoon"):list():add() end,
    { desc = "Harpoon: add this file", group = "Harpoon", tags = "mark pin bookmark" })
map("n", "<C-e>", function()
    local harpoon = require("harpoon")
    harpoon.ui:toggle_quick_menu(harpoon:list())
end, { desc = "Harpoon: quick menu (edit / reorder)", group = "Harpoon", tags = "marks list" })
for i = 1, 4 do
    map("n", "<leader>" .. i, function() require("harpoon"):list():select(i) end,
        { desc = "Harpoon: jump to file " .. i, group = "Harpoon", tags = "switch mark" })
end
map("n", "<leader>hn", function() require("harpoon"):list():next() end,
    { desc = "Harpoon: next file", group = "Harpoon" })
map("n", "<leader>hp", function() require("harpoon"):list():prev() end,
    { desc = "Harpoon: previous file", group = "Harpoon" })
map("n", "<leader>fh", function()
    local paths = {}
    for _, item in ipairs(require("harpoon"):list().items) do
        table.insert(paths, item.value)
    end
    local conf = require("telescope.config").values
    require("telescope.pickers").new({}, {
        prompt_title = "Harpoon",
        finder = require("telescope.finders").new_table({ results = paths }),
        previewer = conf.file_previewer({}),
        sorter = conf.generic_sorter({}),
    }):find()
end, { desc = "Find harpoon files", group = "Harpoon", tags = "marks telescope" })

-- ── Code ───────────────────────────────────────────────────────────────
map({ "n", "x" }, "<leader>cf", function()
    require("conform").format({ async = true })
end, { desc = "Format file or selection", group = "Code", tags = "prettier clang-format ruff indent tidy" })
map("n", "<leader>cd", vim.diagnostic.open_float,
    { desc = "Show diagnostic under cursor", group = "Code", tags = "error message lint warning" })
map("n", "<leader>cl", function()
    -- The command exists once a C / C++ file has loaded the linters (lua/plugins/lint.lua).
    if vim.fn.exists(":LintDeep") == 2 then vim.cmd.LintDeep() else vim.notify("Deep lint: only for C / C++ files") end
end, { desc = "Deep lint: full static analyzer on this file (C / C++)", group = "Code", tags = "clang-tidy analyzer thorough slow bugs" })
map("n", "<leader>cw", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
    { desc = "Replace word under cursor in whole file", group = "Code", tags = "substitute rename", silent = false })
map("n", "]e", function() vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR }) end,
    { desc = "Next error", group = "Code", tags = "diagnostic" })
map("n", "[e", function() vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR }) end,
    { desc = "Previous error", group = "Code", tags = "diagnostic" })

-- ── Run / build (per filetype, see lua/core/run.lua) ───────────────────
map("n", "<leader>rr", function() require("core.run").run() end,
    { desc = "Run current file / project", group = "Run", tags = "execute python node java cmake" })
map("n", "<leader>rb", function() require("core.run").build() end,
    { desc = "Build project (C/C++: cmake or single file)", group = "Run", tags = "compile make cmake" })

-- ── Debug (nvim-dap; C, C++ and Python) ────────────────────────────────
map("n", "<leader>db", function() require("dap").toggle_breakpoint() end, { desc = "Debug: toggle breakpoint", group = "Debug" })
map("n", "<leader>dc", function() require("dap").continue() end, { desc = "Debug: start / continue", group = "Debug", tags = "launch run debugger" })
map("n", "<leader>ds", function() require("dap").step_over() end, { desc = "Debug: step over", group = "Debug" })
map("n", "<leader>di", function() require("dap").step_into() end, { desc = "Debug: step into", group = "Debug" })
map("n", "<leader>do", function() require("dap").step_out() end, { desc = "Debug: step out", group = "Debug" })
map("n", "<leader>dt", function() require("dap").terminate() end, { desc = "Debug: stop session", group = "Debug", tags = "terminate quit" })
map("n", "<leader>du", function() require("dap") require("dapui").toggle() end, { desc = "Debug: toggle UI panels", group = "Debug" })

-- ── Orb: where you left off and what is next (lua/core/memory.lua, tell.lua) ──
map("n", "<leader>on", function() require("core.memory").remind() end,
    { desc = "Orb: say where you left off", group = "Orb", tags = "memory note reminder last time resume now.md" })
map("n", "<leader>oe", function() require("core.memory").edit_note() end,
    { desc = "Orb: edit the where-you-left-off note", group = "Orb", tags = "memory note now.md write" })
map("n", "<leader>op", function() require("core.memory").plan() end,
    { desc = "Orb: plan panel (.orb/plan.md)", group = "Orb", tags = "todo tasks checklist roadmap" })
map("n", "<leader>os", function() require("core.tell").prompt() end,
    { desc = "Orb: tell it the next step (add, tick, move or drop a plan item)", group = "Orb", tags = "say plan next step todo add tick done move reorder drop forget orb say" })
map("n", "<leader>ou", function() require("core.tell").undo() end,
    { desc = "Orb: undo its last change to the plan", group = "Orb", tags = "say plan revert restore orb say --undo" })

-- ── Toggles ────────────────────────────────────────────────────────────
map("n", "<leader>th", function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
    vim.notify("Inlay hints " .. (vim.lsp.inlay_hint.is_enabled() and "on" or "off"))
end, { desc = "Toggle inlay hints", group = "Toggles", tags = "types parameter names" })
map("n", "<leader>tf", function()
    vim.g.format_on_save = not vim.g.format_on_save
    vim.notify("Format on save " .. (vim.g.format_on_save and "on" or "off"))
end, { desc = "Toggle format on save", group = "Toggles", tags = "autoformat" })

-- ── Themes (slots live in lua/core/themes.lua) ─────────────────────────
do
    local themes = require("core.themes")
    for i = 1, math.max(3, #themes.slots) do
        local slot = themes.slots[i]
        map("n", "<leader>t" .. i, function() themes.apply(i) end, {
            desc = "Theme " .. i .. ": " .. (slot and slot.name or "empty slot"),
            group = "Themes",
            tags = "colorscheme colours look switch change",
        })
    end
    map("n", "<leader>tn", themes.next, { desc = "Next theme slot", group = "Themes", tags = "cycle colorscheme switch change" })
    map("n", "<leader>tt", function()
        require("telescope.builtin").colorscheme({ enable_preview = true })
    end, { desc = "Browse all colorschemes with live preview", group = "Themes", tags = "telescope pick theme switch change" })
end

-- ── LSP (buffer-local; called from LspAttach in lua/plugins/lsp.lua) ───
-- Neovim's own defaults stay as they are: K hover, grn rename, gra code
-- action, <C-s> signature help (insert), ]d / [d next / previous diagnostic.
function M.lsp_attach(buf, client_name)
    local function bmap(lhs, rhs, opts)
        opts.buffer = buf
        opts.group = opts.group or "LSP"
        map("n", lhs, rhs, opts)
    end
    bmap("gd", tele("lsp_definitions"), { desc = "Go to definition", tags = "jump declaration source where defined" })
    bmap("gD", vim.lsp.buf.declaration, { desc = "Go to declaration", tags = "header prototype" })
    bmap("gy", tele("lsp_type_definitions"), { desc = "Go to type definition", tags = "class struct of variable" })
    bmap("grr", tele("lsp_references"), { desc = "List references", tags = "usages callers who uses find" })
    bmap("gri", tele("lsp_implementations"), { desc = "List implementations", tags = "interface override subclasses" })
    bmap("gO", tele("lsp_document_symbols"), { desc = "Symbols in this file", tags = "outline functions classes" })
    if client_name == "clangd" then
        bmap("<leader>ch", "<cmd>LspClangdSwitchSourceHeader<cr>",
            { desc = "Switch between header and source", lang = "C/C++", group = "Code", tags = ".h .cpp" })
    end
end

-- ── Git (buffer-local; called from gitsigns on_attach) ─────────────────
function M.git_attach(buf)
    local function gs(fn, ...)
        local args = { ... }
        return function() require("gitsigns")[fn](unpack(args)) end
    end
    local function bmap(mode, lhs, rhs, opts)
        opts.buffer = buf
        opts.group = opts.group or "Git"
        map(mode, lhs, rhs, opts)
    end
    local function selected(fn)
        return function() require("gitsigns")[fn]({ vim.fn.line("."), vim.fn.line("v") }) end
    end
    bmap("n", "]h", gs("nav_hunk", "next"), { desc = "Next changed hunk", tags = "git change diff" })
    bmap("n", "[h", gs("nav_hunk", "prev"), { desc = "Previous changed hunk", tags = "git change diff" })
    bmap("n", "<leader>gs", gs("stage_hunk"), { desc = "Stage hunk (again to unstage)", tags = "git add" })
    bmap("x", "<leader>gs", selected("stage_hunk"), { desc = "Stage selected lines", tags = "git add" })
    bmap("n", "<leader>gr", gs("reset_hunk"), { desc = "Reset hunk (discard change)", tags = "git checkout undo revert" })
    bmap("x", "<leader>gr", selected("reset_hunk"), { desc = "Reset selected lines", tags = "git discard" })
    bmap("n", "<leader>gp", gs("preview_hunk"), { desc = "Preview hunk diff", tags = "git show change" })
    bmap("n", "<leader>gb", gs("blame_line", { full = true }), { desc = "Blame line (full commit)", tags = "git who wrote" })
    bmap("n", "<leader>gd", gs("diffthis"), { desc = "Diff file against index", tags = "git compare" })
    bmap("n", "<leader>tb", gs("toggle_current_line_blame"), { desc = "Toggle inline git blame", group = "Toggles" })
    bmap({ "o", "x" }, "ih", gs("select_hunk"), { desc = "Text object: git hunk", group = "Text objects" })
end

return M
