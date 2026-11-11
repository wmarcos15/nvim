// Hand-written: keys that Neovim itself or a plugin provides by default and that
// are worth knowing with this config. Keys the config binds are NOT listed here;
// they are generated into keymaps.js. Add entries freely.
//   keys   Vim notation        modes  n i x o c
//   src    "Neovim" or the plugin name
window.NVIM_REFERENCE = [
  // ── LSP (Neovim 0.11 defaults) ──────────────────────────────────────
  { keys: "K", modes: ["n"], desc: "Hover: show docs / type of symbol under cursor", group: "LSP", src: "Neovim", tags: "documentation signature info" },
  { keys: "grn", modes: ["n"], desc: "Rename symbol everywhere", group: "LSP", src: "Neovim", tags: "refactor" },
  { keys: "gra", modes: ["n", "x"], desc: "Code action (quick fix, import, refactor)", group: "LSP", src: "Neovim", tags: "fix lightbulb auto import" },
  { keys: "<C-s>", modes: ["i"], desc: "Signature help: show function parameters", group: "LSP", src: "Neovim", tags: "arguments" },
  { keys: "]d", modes: ["n"], desc: "Next diagnostic (opens its message)", group: "Code", src: "Neovim", tags: "error warning lint" },
  { keys: "[d", modes: ["n"], desc: "Previous diagnostic (opens its message)", group: "Code", src: "Neovim", tags: "error warning lint" },
  { keys: "<C-o>", modes: ["n"], desc: "Jump back (e.g. after going to a definition)", group: "Movement", src: "Neovim", tags: "return previous location jumplist" },
  { keys: "<C-i>", modes: ["n"], desc: "Jump forward again", group: "Movement", src: "Neovim", tags: "jumplist" },
  { keys: "<C-^>", modes: ["n"], desc: "Switch to the previous file", group: "Movement", src: "Neovim", tags: "alternate buffer" },

  // ── Comments (built in) ─────────────────────────────────────────────
  { keys: "gcc", modes: ["n"], desc: "Toggle comment on line", group: "Editing", src: "Neovim", tags: "comment out" },
  { keys: "gc", modes: ["n", "x"], desc: "Toggle comment over a motion or selection (gcap, gc3j)", group: "Editing", src: "Neovim", tags: "comment out block" },

  // ── Surround ────────────────────────────────────────────────────────
  { keys: "ys", modes: ["n"], desc: "Surround a motion: ysiw\" wraps the word in quotes", group: "Editing", src: "nvim-surround", tags: "wrap quotes brackets parentheses" },
  { keys: "yss", modes: ["n"], desc: "Surround the whole line", group: "Editing", src: "nvim-surround", tags: "wrap" },
  { keys: "cs", modes: ["n"], desc: "Change surrounding: cs\"' turns \"x\" into 'x'", group: "Editing", src: "nvim-surround", tags: "replace quotes brackets" },
  { keys: "ds", modes: ["n"], desc: "Delete surrounding: ds( removes the parentheses", group: "Editing", src: "nvim-surround", tags: "remove quotes brackets" },
  { keys: "S", modes: ["x"], desc: "Surround the selection", group: "Editing", src: "nvim-surround", tags: "wrap" },

  // ── Editing basics that pair well with the text objects ─────────────
  { keys: ".", modes: ["n"], desc: "Repeat the last change", group: "Editing", src: "Neovim" },
  { keys: "u", modes: ["n"], desc: "Undo", group: "Editing", src: "Neovim" },
  { keys: "<C-r>", modes: ["n"], desc: "Redo", group: "Editing", src: "Neovim" },
  { keys: "]<Space>", modes: ["n"], desc: "Add an empty line below", group: "Editing", src: "Neovim", tags: "blank newline" },
  { keys: "[<Space>", modes: ["n"], desc: "Add an empty line above", group: "Editing", src: "Neovim", tags: "blank newline" },
  { keys: "%", modes: ["n", "x"], desc: "Jump to the matching bracket / if-else / tag", group: "Movement", src: "Neovim", tags: "matchit pair" },
  { keys: "*", modes: ["n"], desc: "Search for the word under the cursor", group: "Movement", src: "Neovim" },
  { keys: "gv", modes: ["n"], desc: "Reselect the last visual selection", group: "Editing", src: "Neovim" },

  // ── Lists ───────────────────────────────────────────────────────────
  { keys: "]q", modes: ["n"], desc: "Next quickfix item", group: "Movement", src: "Neovim", tags: "list results" },
  { keys: "[q", modes: ["n"], desc: "Previous quickfix item", group: "Movement", src: "Neovim", tags: "list results" },
  { keys: "]b", modes: ["n"], desc: "Next buffer", group: "Movement", src: "Neovim" },
  { keys: "[b", modes: ["n"], desc: "Previous buffer", group: "Movement", src: "Neovim" },

  // ── Windows ─────────────────────────────────────────────────────────
  { keys: "<C-w>=", modes: ["n"], desc: "Make all windows the same size", group: "Windows", src: "Neovim", tags: "equalize resize" },
  { keys: "<C-w>o", modes: ["n"], desc: "Close every window except this one", group: "Windows", src: "Neovim", tags: "only" },
  { keys: "<C-w>d", modes: ["n"], desc: "Show diagnostic under cursor (same as <leader>cd)", group: "Code", src: "Neovim" },

  // ── File explorer (netrw, opened with <leader>e) ────────────────────
  { keys: "-", modes: ["n"], desc: "Go up one folder", group: "Files", src: "netrw", where: "in the file explorer" },
  { keys: "<CR>", modes: ["n"], desc: "Open file or folder", group: "Files", src: "netrw", where: "in the file explorer" },
  { keys: "%", modes: ["n"], desc: "Create a new file", group: "Files", src: "netrw", where: "in the file explorer" },
  { keys: "d", modes: ["n"], desc: "Create a new folder", group: "Files", src: "netrw", where: "in the file explorer" },
  { keys: "R", modes: ["n"], desc: "Rename file", group: "Files", src: "netrw", where: "in the file explorer" },
  { keys: "D", modes: ["n"], desc: "Delete file", group: "Files", src: "netrw", where: "in the file explorer" },

  // ── Harpoon menu (<C-e>) ────────────────────────────────────────────
  { keys: "dd", modes: ["n"], desc: "Remove a file from the list (it is a normal buffer: edit, reorder, then close)", group: "Harpoon", src: "harpoon", where: "in the harpoon menu" },
  { keys: "<CR>", modes: ["n"], desc: "Open the file on this line", group: "Harpoon", src: "harpoon", where: "in the harpoon menu" },
  { keys: "q", modes: ["n"], desc: "Close the menu and save the list", group: "Harpoon", src: "harpoon", where: "in the harpoon menu" },

  // ── Commands ────────────────────────────────────────────────────────
  { keys: ":KeymapDocs", modes: ["c"], desc: "Regenerate and open this page", group: "General", src: "config" },
  { keys: ":Lazy", modes: ["c"], desc: "Plugin manager: install, update, remove plugins", group: "General", src: "lazy.nvim", tags: "packages" },
  { keys: ":Mason", modes: ["c"], desc: "Language servers, formatters, debuggers: see what is installed", group: "General", src: "mason.nvim", tags: "lsp install tools" },
  { keys: ":checkhealth vim.lsp", modes: ["c"], desc: "Which language servers are attached to this buffer, and why not", group: "LSP", src: "Neovim", tags: "lspinfo debug troubleshoot" },
  { keys: ":LspRestart", modes: ["c"], desc: "Restart the language servers for this buffer", group: "LSP", src: "nvim-lspconfig", tags: "reload" },
  { keys: ":ConformInfo", modes: ["c"], desc: "Which formatter will run for this file", group: "Code", src: "conform.nvim", tags: "format troubleshoot" },
  { keys: ":ClangdUseBuildDir", modes: ["c"], desc: "Link build/compile_commands.json to the project root for clangd", group: "Code", src: "config", lang: "C/C++", tags: "cmake compilation database" },
  { keys: ":TSUpdate", modes: ["c"], desc: "Update syntax-highlighting parsers", group: "General", src: "nvim-treesitter" },
];
