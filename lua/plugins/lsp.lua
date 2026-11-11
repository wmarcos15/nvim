-- lua/plugins/lsp.lua
--
-- LSP is configured with the Neovim 0.11+ API only:
--   vim.lsp.config(<name>, {...})  -- declare/extend a server config
--   vim.lsp.enable(<name>)         -- turn it on (root detection is lazy, per buffer)
-- nvim-lspconfig is kept ONLY as the provider of the `lsp/<name>.lua` default
-- configs (cmd / filetypes / root_markers / clangd user commands) that
-- vim.lsp.config merges on top of. No `require("lspconfig").<server>.setup()`.
return {
    {
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup({
                ui = {
                    border = "rounded",
                    icons = {
                        package_installed = "✓",
                        package_pending = "➜",
                        package_uninstalled = "✗",
                    },
                },
            })
        end,
    },

    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = { "williamboman/mason.nvim" },
        config = function()
            require("mason-lspconfig").setup({
                ensure_installed = {
                    "clangd",
                    "lua_ls",
                    "pyright",
                    "cmake",
                },
                -- We call vim.lsp.enable() ourselves below, so don't let
                -- mason-lspconfig auto-enable servers behind our back.
                automatic_enable = false,
            })
        end,
    },

    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason-lspconfig.nvim",
            "hrsh7th/cmp-nvim-lsp",
        },
        config = function()
            vim.diagnostic.config({
                virtual_text = true,
                signs = {
                    text = {
                        [vim.diagnostic.severity.ERROR] = " ",
                        [vim.diagnostic.severity.WARN]  = " ",
                        [vim.diagnostic.severity.HINT]  = " ",
                        [vim.diagnostic.severity.INFO]  = " ",
                    },
                },
                underline = true,
                update_in_insert = false,
                severity_sort = true,
                float = {
                    border = "rounded",
                    source = true, -- 0.11: "always" was removed
                },
            })

            -- =============================================
            -- Buffer-local keymaps (same bindings as before,
            -- attached via LspAttach so no per-server on_attach
            -- is needed -- that would clobber the on_attach
            -- shipped by lsp/clangd.lua).
            -- =============================================
            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
                callback = function(ev)
                    local client = vim.lsp.get_client_by_id(ev.data.client_id)
                    if not client then return end

                    local buf = vim.lsp.buf
                    local opts = { noremap = true, silent = true, buffer = ev.buf }

                    vim.keymap.set("n", "gd",         buf.definition,          opts)
                    vim.keymap.set("n", "gD",         buf.declaration,         opts)
                    vim.keymap.set("n", "gi",         buf.implementation,      opts)
                    vim.keymap.set("n", "gr",         buf.references,          opts)
                    vim.keymap.set("n", "gt",         buf.type_definition,     opts)
                    vim.keymap.set("n", "K",          buf.hover,               opts)
                    vim.keymap.set("n", "<C-k>",      buf.signature_help,      opts)
                    vim.keymap.set("n", "<leader>rn", buf.rename,              opts)
                    vim.keymap.set("n", "<leader>ca", buf.code_action,         opts)
                    vim.keymap.set("n", "<leader>cf", function() buf.format({ async = true }) end, opts)
                    vim.keymap.set("n", "<leader>wa", buf.add_workspace_folder,    opts)
                    vim.keymap.set("n", "<leader>wr", buf.remove_workspace_folder, opts)

                    -- 0.11: method-call form (client.supports_method is deprecated)
                    if client:supports_method("textDocument/inlayHint") then
                        vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
                    end
                end,
            })

            -- =============================================
            -- Capabilities shared by every server
            -- =============================================
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            local ok_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
            if ok_cmp then
                capabilities = vim.tbl_deep_extend("force", capabilities, cmp_nvim_lsp.default_capabilities())
            end
            -- Large C/C++ trees produce huge workspace/didChangeWatchedFiles
            -- sets; let the server know we handle dynamic registration.
            capabilities.workspace = capabilities.workspace or {}
            capabilities.workspace.didChangeWatchedFiles = {
                dynamicRegistration = true,
                relativePatternSupport = true,
            }

            vim.lsp.config("*", {
                capabilities = capabilities,
            })

            -- =============================================
            -- C/C++ -- clangd
            -- =============================================
            -- Use roughly half the cores for background indexing so a big
            -- project doesn't saturate the machine on first open.
            local jobs = math.max(2, math.floor((#(vim.uv or vim.loop).cpu_info()) / 2))

            vim.lsp.config("clangd", {
                cmd = {
                    "clangd",
                    "--background-index",             -- index the whole project on disk
                    "--background-index-priority=low", -- keep the editor responsive while indexing
                    "--clang-tidy",                   -- clang-tidy diagnostics inline
                    "--header-insertion=iwyu",        -- include-what-you-use style auto includes
                    "--completion-style=detailed",    -- full signatures in the completion menu
                    "--function-arg-placeholders",
                    "--all-scopes-completion",        -- complete symbols from other namespaces
                    "--pch-storage=memory",           -- faster reparse on large TUs
                    "--enable-config",                -- honour .clangd files (project + user)
                    "--fallback-style=llvm",
                    "--log=error",
                    "-j=" .. jobs,
                },
                -- Root detection: the compilation database wins over everything
                -- else, so a stray .clang-format in a subdirectory of a monorepo
                -- can't pull the root below compile_commands.json.
                -- (Entries in a nested list share the same priority.)
                root_markers = {
                    { "compile_commands.json", "compile_flags.txt", ".clangd" },
                    { "CMakeLists.txt", "Makefile", "meson.build", "configure.ac" },
                    ".git",
                },
                init_options = {
                    usePlaceholders = true,
                    completeUnimported = true,
                    clangdFileStatus = true,
                },
            })
            vim.lsp.enable("clangd")

            -- Warn once per project if clangd started without a compilation
            -- database at the root -- without one you get fallback flags only
            -- (no includes, bogus diagnostics) on a large C/C++ tree.
            local cdb_warned = {}
            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("UserClangdCdbCheck", { clear = true }),
                callback = function(ev)
                    local client = vim.lsp.get_client_by_id(ev.data.client_id)
                    if not client or client.name ~= "clangd" then return end
                    local root = client.config.root_dir
                    if not root or cdb_warned[root] then return end
                    cdb_warned[root] = true

                    local has_cdb = vim.uv.fs_stat(root .. "/compile_commands.json")
                        or vim.uv.fs_stat(root .. "/compile_flags.txt")
                        or vim.uv.fs_stat(root .. "/.clangd")
                    if not has_cdb then
                        vim.notify(
                            ("clangd: no compile_commands.json at %s\n"):format(root)
                                .. "Generate one (cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build)\n"
                                .. "then run :ClangdUseBuildDir, or drop in a .clangd with\n"
                                .. "CompileFlags.CompilationDatabase pointing at your build dir.",
                            vim.log.levels.WARN
                        )
                    end
                end,
            })

            -- :ClangdUseBuildDir [dir]
            -- Symlinks <project>/compile_commands.json -> <dir>/compile_commands.json
            -- (default dir: the first of build/, out/, cmake-build-debug/ that has one)
            -- so clangd finds the database at the project root.
            vim.api.nvim_create_user_command("ClangdUseBuildDir", function(cmd_opts)
                local clients = vim.lsp.get_clients({ name = "clangd", bufnr = 0 })
                local root = clients[1] and clients[1].config.root_dir or vim.fn.getcwd()

                local candidates = cmd_opts.args ~= "" and { cmd_opts.args }
                    or { "build", "out", "cmake-build-debug", "cmake-build-release", "Debug", "Release" }

                for _, dir in ipairs(candidates) do
                    local src = (dir:sub(1, 1) == "/") and dir or (root .. "/" .. dir)
                    src = src .. "/compile_commands.json"
                    if vim.uv.fs_stat(src) then
                        local dest = root .. "/compile_commands.json"
                        if vim.uv.fs_lstat(dest) then
                            vim.notify(dest .. " already exists; leaving it alone.", vim.log.levels.WARN)
                            return
                        end
                        local ok, err = vim.uv.fs_symlink(src, dest)
                        if ok then
                            vim.notify("Linked " .. dest .. " -> " .. src .. "\nRestart clangd with :LspRestart clangd")
                        else
                            vim.notify("symlink failed: " .. tostring(err), vim.log.levels.ERROR)
                        end
                        return
                    end
                end
                vim.notify("No compile_commands.json found under " .. root, vim.log.levels.ERROR)
            end, { nargs = "?", complete = "dir", desc = "Link a build dir's compile_commands.json to the project root" })

            -- =============================================
            -- Lua
            -- =============================================
            vim.lsp.config("lua_ls", {
                settings = {
                    Lua = {
                        runtime = { version = "LuaJIT" },
                        diagnostics = { globals = { "vim" } },
                        workspace = {
                            library = vim.api.nvim_get_runtime_file("", true),
                            checkThirdParty = false,
                        },
                        telemetry = { enable = false },
                    },
                },
            })
            vim.lsp.enable("lua_ls")

            -- =============================================
            -- Python
            -- =============================================
            vim.lsp.config("pyright", {})
            vim.lsp.enable("pyright")

            -- =============================================
            -- CMake
            -- =============================================
            vim.lsp.config("cmake", {})
            vim.lsp.enable("cmake")
        end,
    },
}
