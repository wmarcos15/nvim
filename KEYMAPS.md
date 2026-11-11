# Keymap reference

Every key binding that is live in this config: the ones defined in these files, the
ones that plugins install on their own, and the Neovim 0.11 defaults that are active
alongside them.

- **Leader** is `<Space>` (`<Space>` itself is mapped to `<Nop>` so it never moves the cursor).
- **Local leader** is also `<Space>`.
- `timeoutlen = 300`, so a leader sequence must be typed within 300 ms of the leader.
- Nothing here uses which-key: there is no popup menu listing prefixes while you type.

## Mode legend

| Code | Mode |
|---|---|
| `n` | Normal |
| `v` | Visual **and** Select |
| `x` | Visual only |
| `s` | Select only (inside snippet placeholders) |
| `o` | Operator-pending (after `d`, `y`, `c`, …) |
| `i` | Insert |
| `c` | Command line |
| `t` | Terminal job |

**Global** bindings exist everywhere. **Buffer-local** bindings only exist in buffers
where something attached (an LSP client, gitsigns, a Treesitter parser) and they
*override* a global binding of the same key inside that buffer.

## Inspecting bindings live

| Command | What it shows |
|---|---|
| `:Telescope keymaps` | fuzzy-searchable list of every active mapping |
| `:nmap <C-u>` | what a key is bound to in normal mode |
| `:verbose nmap <C-u>` | the same, plus the file and line that set it |
| `:map <leader>` | every leader sequence |
| `:nmap <buffer>` | only the buffer-local bindings here |
| `:Lazy` → `K` on a plugin | that plugin's `keys` spec |

---

# 1. Core bindings

Defined in `lua/core/keymaps.lua`. All global.

## Windows and splits

| Key | Mode | Action | Notes |
|---|---|---|---|
| `<C-h>` | n | Move to window left | |
| `<C-j>` | n | Move to window below | |
| `<C-k>` | n | Move to window above | Shadowed in LSP buffers by signature help |
| `<C-l>` | n | Move to window right | |
| `<leader>v` | n | `:vertical split` | |
| `<leader>h` | n | `:split` | Ambiguous with gitsigns `<leader>h…` — see §13 |

## Files and session

| Key | Mode | Action |
|---|---|---|
| `<leader>w` | n | Open netrw file explorer (`:Ex`) |
| `<leader>s` | n | Write buffer (`:w`) |
| `<leader>q` | n | Close window (`:q`) |

## Movement

| Key | Mode | Action | Notes |
|---|---|---|---|
| `<C-d>` | n | Half page down, cursor centred | |
| `<C-u>` | n | Half page up, cursor centred | |
| `n` | n | Next search match, centred, folds opened | `nzzzv` |
| `N` | n | Previous search match, centred | `Nzzzv` |

## Visual mode

| Key | Mode | Action |
|---|---|---|
| `<` | v | Indent left and stay in visual mode |
| `>` | v | Indent right and stay in visual mode |
| `J` | v | Move selected lines down and re-indent |
| `K` | v | Move selected lines up and re-indent |

## Clipboard and registers

| Key | Mode | Action | Notes |
|---|---|---|---|
| `<leader>y` | n, v | Yank to system clipboard (`"+y`) | |
| `<leader>Y` | n | Yank line to system clipboard (`"+Y`) | |
| `<leader>p` | v | Paste over selection without clobbering the unnamed register (`"_dP`) | The useful one |
| `<leader>p` | n | Same RHS in normal mode: deletes the character under the cursor into the black hole, then pastes before the cursor | Rarely what you want in normal mode |

## C/C++ workflow

| Key | Mode | Action |
|---|---|---|
| `<leader>ch` | n | Switch between source and header (`:LspClangdSwitchSourceHeader`) |
| `<leader>cb` | n | `:!cmake --build build` |
| `<leader>cr` | n | `:!./build/main` |

## Diagnostics

| Key | Mode | Action |
|---|---|---|
| `<leader>e` | n | Open diagnostic float for the line |
| `[d` | n | Previous diagnostic, with float |
| `]d` | n | Next diagnostic, with float |

## Telescope launchers

| Key | Mode | Action |
|---|---|---|
| `<leader>ff` | n | Find files (includes hidden) |
| `<leader>fg` | n | Live grep |
| `<leader>fb` | n | Open buffers |
| `<leader>fr` | n | Recent files (`oldfiles`) |
| `<leader>fh` | n | Harpoon marks (defined in `harpoon.lua`, see §4) |

---

# 2. LSP

Defined in `lua/plugins/lsp.lua`, attached by the `LspAttach` autocmd. **Buffer-local**:
these exist only in a buffer with an LSP client (C/C++, Lua, Python, CMake here).

| Key | Mode | Action |
|---|---|---|
| `gd` | n | Go to definition |
| `gD` | n | Go to declaration |
| `gi` | n | Go to implementation |
| `gr` | n | List references |
| `gt` | n | Go to type definition |
| `K` | n | Hover documentation |
| `<C-k>` | n | Signature help |
| `<leader>rn` | n | Rename symbol |
| `<leader>ca` | n | Code action (clang-tidy fixes, include insertion, …) |
| `<leader>cf` | n | Format buffer (asynchronous) |
| `<leader>wa` | n | Add workspace folder |
| `<leader>wr` | n | Remove workspace folder |

Inlay hints are enabled automatically for any server that supports them — no toggle key.

---

# 3. Debugging (nvim-dap)

Defined in `lua/plugins/dap.lua` as a lazy `keys` spec: the first press loads nvim-dap.
Global.

| Key | Mode | Action |
|---|---|---|
| `<leader>db` | n | Toggle breakpoint on the current line |
| `<leader>dc` | n | Continue, or start a session if none is running |
| `<leader>ds` | n | Step over |
| `<leader>di` | n | Step into |
| `<leader>do` | n | Step out |
| `<leader>du` | n | Toggle the DAP UI panels |

`<leader>dc` with no session prompts you to pick a configuration:
*Launch executable*, *Launch executable (with args)*, or *Attach to process*.
The UI opens by itself when a session starts and closes when it ends.

## Breakpoint signs

| Sign | Meaning |
|---|---|
| ● | Breakpoint |
| ◆ | Conditional breakpoint |
| ○ | Breakpoint rejected by the debugger (bad line, no debug info) |
| ◇ | Log point |
| ▶ | Current stopped line (whole line highlighted) |

## Inside the DAP UI panels

nvim-dap-ui's own defaults, active in its windows (scopes, stacks, breakpoints, watches):

| Key | Action |
|---|---|
| `<CR>` or double-click | Expand/collapse the entry under the cursor |
| `o` | Open the source location |
| `d` | Remove (breakpoint or watch) |
| `e` | Edit the value or expression |
| `r` | Send the value to the REPL |
| `t` | Toggle the entry |

In the `dap-repl` window: `i` to type, then commands like `.help`, `.scopes`,
`.frames`, `.continue`; `<C-n>` / `<C-p>` walk the REPL history.

---

# 4. Harpoon (file marks)

Defined in `lua/plugins/harpoon.lua` (harpoon2 API). Global.

| Key | Mode | Action | Notes |
|---|---|---|---|
| `<leader>a` | n | Add the current file to the list | |
| `<C-e>` | n | Toggle the quick menu | Costs the built-in scroll-down-one-line |
| `<leader>1` | n | Jump to file 1 | |
| `<leader>2` | n | Jump to file 2 | |
| `<leader>3` | n | Jump to file 3 | |
| `<leader>4` | n | Jump to file 4 | |
| `<leader>mn` | n | Next file in the list | `m` for marks |
| `<leader>mp` | n | Previous file in the list | |
| `<leader>fh` | n | Browse the list in Telescope | Part of the `<leader>f*` find family |

In the quick menu: edit it like a normal buffer (`dd` removes an entry, reorder lines
to reorder files), `<CR>` opens the file under the cursor, `q` or `<Esc>` closes.

---

# 5. Git (gitsigns)

Defined in `lua/plugins/gitsigns.lua`. **Buffer-local**, attached only in files tracked
by git.

| Key | Mode | Action |
|---|---|---|
| `]h` | n | Next hunk |
| `[h` | n | Previous hunk |
| `<leader>hs` | n | Stage hunk |
| `<leader>hs` | v | Stage only the selected lines |
| `<leader>hr` | n | Reset hunk |
| `<leader>hr` | v | Reset only the selected lines |
| `<leader>hp` | n | Preview hunk in a float |
| `<leader>hb` | n | Full blame for the line, in a popup |
| `<leader>hd` | n | Diff this file against the index |
| `<leader>tb` | n | Toggle the inline end-of-line blame |
| `<leader>td` | n | Toggle showing deleted lines |

Inline blame is **on** by default, appearing at end of line after 500 ms.

---

# 6. Treesitter text objects

Defined in `lua/plugins/treesitter.lua`. **Buffer-local**, present wherever a parser is
active (c, cpp, cmake, lua, vim, python, bash, markdown, json, yaml).

## Select — use after an operator, or in visual mode

| Key | Mode | Selects |
|---|---|---|
| `af` / `if` | o, x | A function / a function body |
| `ac` / `ic` | o, x | A class / a class body |
| `aa` / `ia` | o, x | An argument, with/without the comma |
| `ai` / `ii` | o, x | A conditional / its body |
| `al` / `il` | o, x | A loop / its body |

So `daf` deletes a whole function, `vif` selects its body, `cia` changes one argument.
Lookahead is on: if the cursor is before the construct, it jumps forward to it.

## Swap

| Key | Mode | Action |
|---|---|---|
| `<leader>sn` | n | Swap this argument/parameter with the next |
| `<leader>sp` | n | Swap this argument/parameter with the previous |

## Move

| Key | Mode | Action |
|---|---|---|
| `]f` / `[f` | n, x, o | Next / previous function start |
| `]F` / `[F` | n, x, o | Next / previous function **end** |
| `]c` / `[c` | n, x, o | Next / previous class start |
| `]C` / `[C` | n, x, o | Next / previous class **end** |
| `]a` / `[a` | n, x, o | Next / previous argument |

These set the jumplist, so `<C-o>` takes you back where you started.

---

# 7. Completion (nvim-cmp)

Defined in `lua/plugins/completion.lua`. Insert mode, only while the completion menu
logic is active. Completion is suppressed inside comments.

| Key | Mode | Action |
|---|---|---|
| `<C-Space>` | i | Trigger completion manually |
| `<C-k>` | i | Previous item |
| `<C-j>` | i | Next item |
| `<Tab>` | i, s | Next item if the menu is open; otherwise expand/jump a snippet; otherwise a literal tab |
| `<S-Tab>` | i, s | Previous item, or jump backwards in a snippet |
| `<C-b>` | i | Scroll documentation up |
| `<C-f>` | i | Scroll documentation down |
| `<C-e>` | i | Abort completion |
| `<CR>` | i | Confirm — **only** if you explicitly selected an item (`select = false`); otherwise it inserts a newline, with autopairs handling the brackets |

Sources are ranked LSP → snippets → buffer words → paths, and the menu is tagged
`[LSP]`, `[Snip]`, `[Buf]`, `[Path]`.

## Command line

| Key | Mode | Action |
|---|---|---|
| `<Tab>` | c | Next candidate, or open the menu if closed |
| `<S-Tab>` | c | Previous candidate, or open the menu |
| `<C-n>` / `<C-p>` | c | Next / previous candidate (falls through if the menu is closed) |
| `<C-z>` | c | Same as `<Tab>` |
| `<C-y>` | c | Confirm the candidate |
| `<C-e>` | c | Abort |

`/` searches complete from buffer words; `:` completes paths and commands.

---

# 8. Snippets

LuaSnip, driven through the cmp `<Tab>` / `<S-Tab>` bindings above. `friendly-snippets`
is loaded, which includes the C and C++ collections.

Neovim's own snippet keys are also live (they apply to `vim.snippet`, which LSP
snippets use):

| Key | Mode | Action |
|---|---|---|
| `<Tab>` | s | Jump to the next placeholder |
| `<S-Tab>` | s | Jump to the previous placeholder |
| `<C-s>` | i, s | Signature help |

---

# 9. Surround (nvim-surround)

Plugin defaults; nothing is customised. `{char}` is the delimiter — `(`, `"`, `{`, a tag
name, …

| Key | Mode | Action |
|---|---|---|
| `ys{motion}{char}` | n | Surround the motion |
| `yss{char}` | n | Surround the whole line |
| `yS{motion}{char}` | n | Surround, delimiters on their own lines |
| `ySS{char}` | n | Surround the line, delimiters on their own lines |
| `ds{char}` | n | Delete the surrounding pair |
| `cs{old}{new}` | n | Change the surrounding pair |
| `cS{old}{new}` | n | Change it, putting replacements on new lines |
| `S{char}` | x | Surround the visual selection |
| `gS{char}` | x | Surround the selection, on new lines |
| `<C-g>s{char}` | i | Surround the cursor position |
| `<C-g>S{char}` | i | The same, on new lines |

Examples: `ysiw"` quotes a word, `cs"'` turns `"x"` into `'x'`, `ds(` strips parentheses.

---

# 10. Inside a Telescope picker

Customised in `lua/plugins/telescope.lua`; everything else is a Telescope default.
Pickers open in insert mode.

## Customised

| Key | Mode | Action |
|---|---|---|
| `<C-k>` | i | Previous result |
| `<C-j>` | i | Next result |
| `<C-q>` | i | Send selected results to the quickfix list and open it |
| `<Esc>` | i | Close the picker (does *not* drop to normal mode) |
| `q` | n | Close the picker |

## Defaults still in effect

| Key | Mode | Action |
|---|---|---|
| `<CR>` | i, n | Open the selection |
| `<C-x>` | i, n | Open in a horizontal split |
| `<C-v>` | i, n | Open in a vertical split |
| `<C-t>` | i, n | Open in a new tab |
| `<C-n>` / `<C-p>` | i | Next / previous result |
| `<Down>` / `<Up>` | i, n | Next / previous result |
| `<Tab>` / `<S-Tab>` | i, n | Toggle multi-selection and move |
| `<C-u>` / `<C-d>` | i, n | Scroll the preview up / down |
| `<PageUp>` / `<PageDown>` | i, n | Scroll the results list |
| `<C-c>` | i | Close |
| `<C-/>` | i | Show all keys for this picker |
| `?` | n | Show all keys for this picker |
| `j` / `k`, `gg` / `G`, `H` / `M` / `L` | n | Move within the results |

Note `<C-u>` inside a picker scrolls the preview rather than paging the buffer.

---

# 11. Neovim 0.11 defaults that are live

Not in any config file, but active and worth knowing because several overlap with the
bindings above.

## LSP defaults (alongside this config's `gd`/`gr`/… )

| Key | Mode | Action |
|---|---|---|
| `grn` | n | Rename |
| `gra` | n, x | Code action |
| `grr` | n | References |
| `gri` | n | Implementation |
| `grt` | n | Type definition |
| `gO` | n | Document symbols |
| `K` | n | Hover |
| `<C-s>` | i, s | Signature help |

## Diagnostics

| Key | Mode | Action |
|---|---|---|
| `]d` / `[d` | n | Next / previous diagnostic — **overridden** in §1 (same behaviour, new API) |
| `]D` / `[D` | n | Last / first diagnostic in the buffer |
| `<C-w>d` | n | Show the diagnostic under the cursor in a float |

## Commenting (built in since 0.10 — no plugin)

| Key | Mode | Action |
|---|---|---|
| `gcc` | n | Toggle comment on the line |
| `gc{motion}` | n | Toggle comment over a motion |
| `gc` | x | Toggle comment on the selection |
| `gc` | o | Comment text object, e.g. `dgc` deletes a comment block |

## Quickfix, buffers, and friends

| Key | Mode | Action |
|---|---|---|
| `]q` / `[q` | n | Next / previous quickfix item (`:cnext` / `:cprevious`) |
| `]Q` / `[Q` | n | Last / first quickfix item |
| `]l` / `[l` | n | Next / previous location-list item |
| `]b` / `[b` | n | Next / previous buffer |
| `]a` / `[a` | n | Next / previous file in the arglist |
| `]t` / `[t` | n | Next / previous tag match |
| `]<Space>` / `[<Space>` | n | Add an empty line below / above |
| `gx` | n, x | Open the file path or URL under the cursor with the system handler |
| `Y` | n | Yank to end of line (`y$`) |
| `&` | n | Repeat the last `:s` with the same flags |

## matchit (bundled plugin)

| Key | Mode | Action |
|---|---|---|
| `%` | n, x, o | Jump between matching pairs, including `#if` / `#else` / `#endif` |
| `[%` / `]%` | n, x, o | Jump to the start / end of the surrounding block |
| `g%` | n, x, o | Jump backwards through the match group |
| `a%` | x | Select the matching block |

Handy in C: `%` on `#ifdef` jumps to its `#endif`.

---

# 12. Plugin manager and tool UIs

## `:Lazy`

| Key | Action |
|---|---|
| `I` / `i` | Install missing plugins / install the one under the cursor |
| `U` / `u` | Update all / update this one |
| `S` | Sync (install + clean + update) |
| `X` / `x` | Clean plugins no longer in the spec |
| `C` / `c` | Check for updates (git fetch) |
| `L` | Show recent updates |
| `R` / `r` | Restore everything to `lazy-lock.json` |
| `P` | Profiling view |
| `D` | Debug info |
| `H` | Back to the plugin list |
| `<CR>` | Expand details for the plugin under the cursor |
| `K` | Show its spec and keys |
| `d` | Show its diff |
| `?` | Toggle help |
| `q` | Close |
| `]]` / `[[` | Next / previous section |

## `:Mason`

| Key | Action |
|---|---|
| `<CR>` | Expand the package under the cursor |
| `i` | Install it |
| `u` / `U` | Update it / update all installed |
| `c` / `C` | Check its version / check all for updates |
| `X` | Uninstall it |
| `<C-c>` | Cancel a running installation |
| `g?` | Help |
| `q` | Close |

## netrw (`<leader>w`)

| Key | Action |
|---|---|
| `<CR>` | Open the file or directory |
| `-` | Go up one directory |
| `%` | Create a new file |
| `d` | Create a new directory |
| `D` | Delete the entry under the cursor |
| `R` | Rename it |
| `i` | Cycle the listing style |
| `s` | Cycle the sort order |

Full list: `:help netrw-quickmap`.

---

# 13. Conflicts, shadowing, and gotchas

## Precedence

1. A **buffer-local** mapping beats a global one in that buffer.
2. Among global mappings, **the last one set wins** — plugins configured by lazy.nvim
   run *after* `lua/core/keymaps.lua`, so a plugin always wins a straight collision.
3. A longer sequence beats a shorter prefix only if you finish typing it within
   `timeoutlen` (300 ms).

## Keys that are overridden

| Key | Intended | What actually runs | Where |
|---|---|---|---|
| `<C-k>` | Window above (core) | Signature help, **in LSP buffers only** | `lsp.lua:91` |
| `<C-e>` | Scroll down one line (Vim built-in) | Harpoon quick menu | `harpoon.lua:27` |
| `]d` / `[d` | Neovim default diagnostic jump | Same thing via the 0.11 API | `keymaps.lua:75` |

That is the whole list. Harpoon used to take `<C-h>`, `<C-u>`, `<C-i>`, `<C-o>` and
`<C-p>`; its navigation now lives on `<leader>1`–`<leader>4`, `<leader>mn` /
`<leader>mp` and `<leader>fh`, so window-left, half-page-up and — most importantly —
the jumplist (`<C-o>` / `<C-i>`) all behave normally again. After `gd` you can press
`<C-o>` to come back; `<C-t>` also works, since LSP definition jumps push the tag
stack.

`<C-e>` is kept on purpose: it is harpoon's own documented key and it only costs the
built-in scroll-down-one-line.

**Terminal caveat.** `<C-i>` and `<Tab>` are the same byte unless your terminal supports
CSI-u encoding (kitty, WezTerm, recent Alacritty; iTerm2 needs it enabled), as are
`<C-h>` and `<BS>`. Nothing here maps `<C-i>` any more, so this no longer costs you
anything — but keep it in mind before binding `<C-i>` or `<C-h>` to something new.

## Built-in Vim keys taken over in attached buffers

These are plain Vim/Neovim commands that a buffer-local mapping replaces once an LSP
client or a Treesitter parser attaches. They still work in buffers without one.

| Key | Vim built-in | What it does here | Where |
|---|---|---|---|
| `gi` | Insert at the last insert position | Go to implementation | `lsp.lua:87` |
| `gt` | Go to the next tab page | Go to type definition | `lsp.lua:89` |
| `gr` | `gr{char}`, virtual replace | List references | `lsp.lua:88` |
| `K` | Run `keywordprg` (man page) | Hover documentation | `lsp.lua:90` |
| `]c` / `[c` | Next / previous change **in diff mode** | Next / previous class | `treesitter.lua:86,95` |
| `]a` / `[a` | Next / previous arglist file | Next / previous argument | `treesitter.lua:87,96` |

The `]c` / `[c` one is easy to trip over: after `<leader>hd` (gitsigns diff) or `:diffthis`
in a C++ file, `]c` moves by class instead of by diff hunk. Use `]h` / `[h` for hunks,
or `:diffget` / `:diffput` directly.

## Leader prefixes that are also complete commands

Each of these fires the short version after 300 ms of hesitation:

| Prefix | Fires alone | Longer sequences underneath |
|---|---|---|
| `<leader>h` | `:split` | `<leader>hs` `hr` `hp` `hb` `hd` (gitsigns) |
| `<leader>s` | `:w` | `<leader>sn` `sp` (swap arguments) |
| `<leader>w` | `:Ex` | `<leader>wa` `wr` (workspace folders) |

Type the two-key versions briskly, or they become "split", "write", "explorer".

## Same key, different modes — not conflicts

`<C-k>` is window-up (n), previous completion item (i), and previous result (Telescope i).
`<C-e>` is the Harpoon menu (n) and abort-completion (i). `<C-u>` is half-page-up (n),
delete-to-start-of-line (i), and scroll-preview (Telescope). `K` is hover (n) and
move-lines-up (v). `J` is join (n, built-in) and move-lines-down (v). All fine.

## Not bound to anything

No keys for: toggling inlay hints (always on), restarting the LSP (`:LspRestart`),
`:ClangdUseBuildDir`, toggling diagnostics virtual text, resizing windows, tab pages,
or the terminal. Add them in `lua/core/keymaps.lua` for global ones, or in the relevant
plugin spec for anything that needs the plugin loaded.

---

# 14. A C/C++ session, in order

```
<leader>ff          find a file               <leader>fg   grep the project
gd                  jump to definition        K            read the docs
<C-o>               jump back                 <leader>ch   header <-> source
<leader>a           harpoon this file         <leader>1-4  snap between harpooned files
]f / [f             next/previous function    daf          delete a whole function
<leader>ca          apply a clang-tidy fix    <leader>rn   rename across the project
<leader>e           read the error            ]d           go to the next one
<leader>cf          format                    <leader>hs   stage the hunk
<leader>cb          cmake --build build       <leader>db   breakpoint
<leader>dc          start debugging           <leader>ds   step over
<leader>du          open the variables panel  <leader>dc   continue to the next stop
```
