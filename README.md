# Neovim config

Keyboard-driven, few plugins, no file tree or bufferline. Telescope and Harpoon
do the navigation; language servers do the rest. Needs Neovim 0.11+.

**Keymaps:** press `Space ?` (or run `:KeymapDocs`) for the searchable keymap
reference. It is generated from the live config, so it is always current.

## Languages

| Language | Language server | Lint | Format (`Space c f`) | Debug (`Space d …`) | Run (`Space r r`) |
|---|---|---|---|---|---|
| C / C++ | clangd | clang-tidy (live), cppcheck + clang static analyzer (on save) | clang-format | codelldb | cmake, or the single file |
| Python | pyright | ruff | ruff | debugpy | python (project venv if present) |
| JavaScript / TypeScript | vtsls | eslint (projects with an ESLint config) | prettier | – | node / `npx tsx` |
| Java | jdtls | jdtls | jdtls | – | `java File.java` |
| Lua, CMake | lua_ls, cmake | – | language server | – | – |

Everything in the table except cppcheck and the JDK is installed automatically
by Mason on first start (`:Mason` to look).

Things to install yourself:

- `brew install cppcheck` — C/C++ linting on save (skipped silently if missing).
- **A JDK 25+** for the Java language server, e.g. `brew install openjdk@25`.
  jdtls is a Java program and needs that to *run*; your projects and your
  default `java` are unaffected. The config finds the JDK by itself.
- `ripgrep` for project search, a Nerd Font for icons.

## Layout

```
init.lua                 load order
lua/core/
  options.lua            editor settings
  keymaps.lua            EVERY keymap (plus the registry the docs are built from)
  themes.lua             theme slots  <- edit this to add / change themes
  cursor.lua             cursor colour by mode / on errors (for slots that ask)
  start.lua              the start screen
  orb.lua                shows / hides the Orb background (~/.config/orb)
  marks.lua              the Orb's marks: small dials beside lines with problems
  run.lua                what "run" and "build" mean per language
  autocmds.lua           small automations (yank flash, restore cursor, ...)
  docs.lua               :KeymapDocs
  lazy.lua               plugin manager bootstrap
lua/plugins/             one file per area; plugin setup only, no keymaps
  lsp.lua                language servers + the list of tools Mason installs
  lint.lua               on-save linters      format.lua   formatters
  telescope.lua  harpoon.lua  gitsigns.lua  treesitter.lua
  completion.lua  dap.lua  editing.lua  ui.lua
docs/                    the keymap web page (index.html + generated keymaps.js)
scripts/check.lua        self-test (see below)
templates/clangd         starter .clangd for a C/C++ project
```

## Keymap rules

- Leader is `Space`. Groups: `f` find, `c` code, `g` git, `d` debug, `r` run,
  `t` toggles and themes, `s` swap arguments, `h` harpoon next/previous.
- No key is a prefix of another, so nothing waits on a timeout.
  `scripts/check.lua` enforces this.
- Neovim's own defaults are kept where they exist (`K`, `grn`, `gra`, `]d`,
  `gcc`, …) instead of being remapped.
- Add a keymap with `map(...)` in `lua/core/keymaps.lua`. Give it a `desc`, a
  `group`, and optional `tags` (extra search words); it then shows up in the
  docs by itself.

## Themes

`Space t 1` / `t 2` / `t 3` switch theme slots, `Space t n` cycles,
`Space t t` previews every installed colorscheme in Telescope. The last choice
is remembered.

| Slot | Theme | Background |
|---|---|---|
| 1 | Kanagawa Wave | transparent: your terminal's background or image shows through |
| 2 | Cyberdream HUD (control centre) | the Orb in Ghostty; solid near-black elsewhere |
| 3 | VS Code Dark | solid neutral grey, easy on the eye |

### The Orb (slot 2's background)

Neovim cannot draw behind its own text, but Ghostty can run a shader over the
whole window. The Orb is that shader: an instrument dial in the top-right
corner, a dot matrix and small effects, all fading out around text. It is its
own project in `~/.config/orb` (see its README for setup, tuning, the browser
preview and the `orb` shell command); this config is one of its clients.

- Slot 2 shows the orb, slots 1 and 3 hide it, and quitting Neovim hands the
  terminal back as the `orb` command left it. See `lua/core/orb.lua`.
- The orb takes the cursor's colour, which slot 2 changes with the mode (cyan
  normal, amber insert, indigo visual). In normal mode it also turns yellow
  while the file has a warning, red for an error, and violet with a spinner
  while a run / build or a language server is working. See `lua/core/cursor.lua`.
- A small copy of the dial sits in the sign column on every line with an
  error (red) or a warning (yellow). See `lua/core/marks.lua`.
- `:OrbInfo` shows whether everything it needs is in place. In iTerm or any
  other terminal, or without the orb project, slot 2 uses a solid background.

### Adding or changing a theme

1. New plugin? Add it to `lua/plugins/ui.lua` with `lazy = true`.
2. Add or edit an entry in `M.slots` in `lua/core/themes.lua` (the fields are
   documented at the top of that file). A 4th entry gets `Space t 4` on its own.
3. Restart Neovim. The docs page picks up the new slot's colours too.

## Start screen

`nvim` with no file shows recent files (press `1`–`8`, or Enter on a line) and
a few key reminders taken from the live keymaps. See `lua/core/start.lua`.

## Self-test

```
nvim --headless -c "luafile scripts/check.lua"
```

Opens a sample file per language and checks that the servers attach, linters
report, formatters resolve, no keymaps collide, the docs generate and every
theme slot applies. Run it after changing the config or updating plugins.

## Adding a language

1. Add its Mason package names to `tools` in `lua/plugins/lsp.lua` and its
   server name to the `vim.lsp.enable({...})` list there.
2. Optional: a formatter in `lua/plugins/format.lua`, a linter in
   `lua/plugins/lint.lua`, a run command in `lua/core/run.lua`, a treesitter
   parser in `lua/plugins/treesitter.lua`.
