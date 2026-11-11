-- lua/plugins/lsp.lua
--
-- Language servers, on the Neovim 0.11 native API:
--   vim.lsp.config(<name>, {...})  extend a server's config
--   vim.lsp.enable(<name>)         turn it on
-- nvim-lspconfig only supplies the default per-server configs (lsp/<name>.lua).
--
--   C / C++      clangd (+ clang-tidy checks)
--   Python       pyright (types, navigation) + ruff (lint, format)
--   JS / TS      vtsls + eslint (lint; only in projects with an ESLint config)
--   Java         jdtls, run on a new enough JDK found on this machine
--   Lua, CMake   lua_ls, cmake
--
-- Keymaps: lua/core/keymaps.lua (lsp_attach).  Formatting: plugins/format.lua.
-- Extra on-save linters: plugins/lint.lua.

-- Everything Mason should keep installed (servers, formatters, debug adapters).
local tools = {
    "clangd", "clang-format", "codelldb",        -- C / C++
    "pyright", "ruff", "debugpy",                -- Python
    "vtsls", "eslint-lsp", "prettier",           -- JavaScript / TypeScript
    "jdtls",                                     -- Java
    "lua-language-server", "cmake-language-server",
}

return {
    {
        "mason-org/mason.nvim",
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

            -- Install anything from `tools` that is missing.
            local registry = require("mason-registry")
            registry.refresh(function()
                for _, name in ipairs(tools) do
                    local ok, pkg = pcall(registry.get_package, name)
                    if ok and not pkg:is_installed() and not pkg:is_installing() then
                        vim.notify("Mason: installing " .. name)
                        pkg:install()
                    end
                end
            end)
        end,
    },

    -- Small "indexing… 42%" progress messages in the corner
    { "j-hui/fidget.nvim", opts = {} },

    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "mason-org/mason.nvim",
            "hrsh7th/cmp-nvim-lsp",
        },
        config = function()
            local sev = vim.diagnostic.severity
            vim.diagnostic.config({
                virtual_text = true,
                signs = {
                    text = {
                        [sev.ERROR] = "\u{f057}",
                        [sev.WARN]  = "\u{f071}",
                        [sev.HINT]  = "\u{f0eb}",
                        [sev.INFO]  = "\u{f05a}",
                    },
                },
                underline = true,
                update_in_insert = false,
                severity_sort = true,
                float = { border = "rounded", source = true },
                jump = { float = true }, -- ]d / [d open the message too
            })

            vim.lsp.inlay_hint.enable(true) -- toggle with <leader>th

            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
                callback = function(ev)
                    local client = vim.lsp.get_client_by_id(ev.data.client_id)
                    if not client then return end

                    require("core.keymaps").lsp_attach(ev.buf, client.name)

                    -- pyright already provides hover; ruff's would duplicate it
                    if client.name == "ruff" then
                        client.server_capabilities.hoverProvider = false
                    end

                    -- Highlight other uses of the symbol under the cursor
                    if client:supports_method("textDocument/documentHighlight") then
                        local group = vim.api.nvim_create_augroup("UserLspHighlight" .. ev.buf, { clear = true })
                        vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                            group = group, buffer = ev.buf, callback = vim.lsp.buf.document_highlight,
                        })
                        vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
                            group = group, buffer = ev.buf, callback = vim.lsp.buf.clear_references,
                        })
                    end
                end,
            })

            -- Capabilities shared by every server
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            local ok_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
            if ok_cmp then
                capabilities = vim.tbl_deep_extend("force", capabilities, cmp_nvim_lsp.default_capabilities())
            end
            capabilities.workspace = capabilities.workspace or {}
            capabilities.workspace.didChangeWatchedFiles = {
                dynamicRegistration = true,
                relativePatternSupport = true,
            }
            vim.lsp.config("*", { capabilities = capabilities })

            -- =============================================
            -- C / C++ -- clangd
            -- =============================================
            -- Roughly half the cores for background indexing, so a big
            -- project doesn't saturate the machine on first open.
            local jobs = math.max(2, math.floor(#vim.uv.cpu_info() / 2))

            vim.lsp.config("clangd", {
                cmd = {
                    "clangd",
                    "--background-index",
                    "--background-index-priority=low",
                    "--clang-tidy",
                    "--header-insertion=iwyu",
                    "--completion-style=detailed",
                    "--function-arg-placeholders=1",
                    "--all-scopes-completion",
                    "--pch-storage=memory",
                    "--enable-config", -- honour .clangd files
                    "--fallback-style=llvm",
                    "--log=error",
                    "-j=" .. jobs,
                },
                -- The compilation database wins over everything else.
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

            -- Warn once per project if clangd started without a compilation
            -- database: without one you get fallback flags only.
            local cdb_warned = {}
            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("UserClangdCdbCheck", { clear = true }),
                callback = function(ev)
                    local client = vim.lsp.get_client_by_id(ev.data.client_id)
                    if not client or client.name ~= "clangd" then return end
                    local root = client.config.root_dir
                    if not root or cdb_warned[root] then return end
                    cdb_warned[root] = true

                    -- A lone file with no project around it is fine on fallback flags.
                    local is_project = vim.uv.fs_stat(root .. "/CMakeLists.txt")
                        or vim.uv.fs_stat(root .. "/Makefile")
                        or vim.uv.fs_stat(root .. "/meson.build")
                    local has_cdb = vim.uv.fs_stat(root .. "/compile_commands.json")
                        or vim.uv.fs_stat(root .. "/compile_flags.txt")
                        or vim.uv.fs_stat(root .. "/.clangd")
                    if is_project and not has_cdb then
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
            -- Python -- pyright + ruff
            -- =============================================
            vim.lsp.config("pyright", {
                settings = {
                    pyright = { disableOrganizeImports = true }, -- ruff does it
                },
            })

            -- =============================================
            -- JavaScript / TypeScript -- vtsls + eslint
            -- =============================================
            local ts_hints = {
                inlayHints = {
                    parameterNames = { enabled = "literals" },
                    variableTypes = { enabled = true },
                    functionLikeReturnTypes = { enabled = true },
                },
            }
            vim.lsp.config("vtsls", {
                settings = { typescript = ts_hints, javascript = ts_hints },
            })

            -- =============================================
            -- Lua (for editing this config)
            -- =============================================
            vim.lsp.config("lua_ls", {
                settings = {
                    Lua = {
                        runtime = { version = "LuaJIT" },
                        diagnostics = { globals = { "vim" } },
                        workspace = {
                            library = { vim.env.VIMRUNTIME },
                            checkThirdParty = false,
                        },
                        telemetry = { enable = false },
                    },
                },
            })

            -- =============================================
            -- Java -- jdtls
            -- =============================================
            -- jdtls is itself a Java program and needs a recent JDK to *run*
            -- (JAVA_MIN below), whatever Java version your project targets and
            -- whatever your default `java` is. So: look for a new enough JDK
            -- on this machine and launch jdtls with that one. If there is
            -- none, jdtls is not started and you get one message saying so.
            -- Force a specific JDK with the JDTLS_JAVA_HOME environment variable.
            local JAVA_MIN = 25 -- required by the jdtls version Mason installs today

            local function jdk_major(home)
                local ok, lines = pcall(vim.fn.readfile, home .. "/release")
                if not ok then return nil end
                for _, line in ipairs(lines) do
                    local major = line:match('^JAVA_VERSION="(%d+)')
                    if major then return tonumber(major) end
                end
            end

            local jdtls_java_home -- nil = not looked up yet, false = none found
            local function find_jdk()
                if jdtls_java_home ~= nil then return jdtls_java_home end
                jdtls_java_home = false
                if vim.env.JDTLS_JAVA_HOME then
                    jdtls_java_home = vim.env.JDTLS_JAVA_HOME
                    return jdtls_java_home
                end
                local best = 0
                for _, pattern in ipairs({
                    "~/Library/Java/JavaVirtualMachines/*/Contents/Home",
                    "/Library/Java/JavaVirtualMachines/*/Contents/Home",
                    "/opt/homebrew/opt/openjdk*/libexec/openjdk.jdk/Contents/Home",
                    "/usr/local/opt/openjdk*/libexec/openjdk.jdk/Contents/Home",
                    "/usr/lib/jvm/*",
                }) do
                    for _, home in ipairs(vim.fn.glob(pattern, true, true)) do
                        local major = jdk_major(home)
                        if major and major >= JAVA_MIN and major > best then
                            best, jdtls_java_home = major, home
                        end
                    end
                end
                if not jdtls_java_home then
                    vim.notify(
                        ("jdtls (Java language server) needs JDK %d or newer to run, and none was found.\n"):format(JAVA_MIN)
                            .. ("Install one, e.g.  brew install openjdk@%d  then reopen the file.\n"):format(JAVA_MIN)
                            .. "Your project and your default `java` are not affected.",
                        vim.log.levels.WARN
                    )
                end
                return jdtls_java_home
            end

            local jdtls_defaults = vim.lsp.config.jdtls -- from nvim-lspconfig
            vim.lsp.config("jdtls", {
                -- Only start when a usable JDK exists (on_dir is what starts the server).
                root_dir = function(bufnr, on_dir)
                    if find_jdk() then on_dir(vim.fs.root(bufnr, jdtls_defaults.root_markers)) end
                end,
                cmd = function(dispatchers, config)
                    config.cmd_env = vim.tbl_extend("force", config.cmd_env or {}, { JAVA_HOME = find_jdk() or nil })
                    return jdtls_defaults.cmd(dispatchers, config)
                end,
            })

            vim.lsp.enable({ "clangd", "pyright", "ruff", "vtsls", "eslint", "jdtls", "lua_ls", "cmake" })
        end,
    },
}
