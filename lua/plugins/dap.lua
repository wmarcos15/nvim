-- lua/plugins/dap.lua
--
-- Debugging with nvim-dap + nvim-dap-ui.
--   C / C++   codelldb
--   Python    debugpy
-- Both adapters are installed by Mason (see `tools` in plugins/lsp.lua).
-- Keymaps (<leader>d*): lua/core/keymaps.lua. A project's .vscode/launch.json
-- is picked up automatically.
return {
    {
        "mfussenegger/nvim-dap",
        lazy = true, -- loads the first time a <leader>d key is pressed
        dependencies = {
            {
                "rcarriga/nvim-dap-ui",
                dependencies = { "nvim-neotest/nvim-nio" },
            },
        },

        config = function()
            local dap = require("dap")
            local dapui = require("dapui")

            -- =============================================
            -- UI
            -- =============================================
            dapui.setup({
                icons = { expanded = "\u{25be}", collapsed = "\u{25b8}", current_frame = "\u{25b8}" },
                layouts = {
                    {
                        position = "left",
                        size = 42,
                        elements = {
                            { id = "scopes",      size = 0.35 },
                            { id = "breakpoints", size = 0.15 },
                            { id = "stacks",      size = 0.25 },
                            { id = "watches",     size = 0.25 },
                        },
                    },
                    {
                        position = "bottom",
                        size = 10,
                        elements = {
                            { id = "repl",    size = 0.5 },
                            { id = "console", size = 0.5 },
                        },
                    },
                },
                floating = { border = "rounded" },
            })

            -- Open/close the UI automatically with the debug session
            dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
            dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
            dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

            -- Gutter signs (plain Unicode shapes: no nerd font required)
            vim.fn.sign_define("DapBreakpoint",          { text = "\u{25cf}", texthl = "DiagnosticError", numhl = "" })
            vim.fn.sign_define("DapBreakpointCondition", { text = "\u{25c6}", texthl = "DiagnosticWarn",  numhl = "" })
            vim.fn.sign_define("DapBreakpointRejected",  { text = "\u{25cb}", texthl = "DiagnosticHint",  numhl = "" })
            vim.fn.sign_define("DapLogPoint",            { text = "\u{25c7}", texthl = "DiagnosticInfo",  numhl = "" })
            vim.fn.sign_define("DapStopped",             { text = "\u{25b6}", texthl = "DiagnosticOk",    linehl = "Visual", numhl = "" })

            -- =============================================
            -- codelldb adapter (installed by Mason)
            -- =============================================
            -- Resolved when a session starts, not at config time, so a
            -- codelldb that Mason installs later in the session is picked up
            -- without restarting Neovim.
            local function codelldb_path()
                local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/codelldb"
                if vim.fn.executable(mason_bin) == 1 then
                    return mason_bin
                end
                return "codelldb" -- fall back to $PATH
            end

            dap.adapters.codelldb = function(on_adapter)
                on_adapter({
                    type = "server",
                    port = "${port}",
                    executable = {
                        command = codelldb_path(),
                        args = { "--port", "${port}" },
                    },
                })
            end

            -- =============================================
            -- C/C++ launch configurations
            -- =============================================
            -- Remember the last binary so repeated <leader>dc runs don't
            -- re-prompt for the path on every session.
            local last_program = nil

            local function pick_program()
                local root = vim.fs.root(0, { "compile_commands.json", ".clangd", "CMakeLists.txt", ".git" })
                    or vim.fn.getcwd()
                local default = last_program or (root .. "/build/")
                local path = vim.fn.input({ prompt = "Path to executable: ", default = default, completion = "file" })
                if path == nil or path == "" then
                    return nil -- aborts the session
                end
                last_program = path
                return vim.fn.exepath(path) ~= "" and vim.fn.exepath(path) or path
            end

            local cpp_configs = {
                {
                    name = "Launch executable",
                    type = "codelldb",
                    request = "launch",
                    program = pick_program,
                    cwd = "${workspaceFolder}",
                    stopOnEntry = false,
                    args = {},
                },
                {
                    name = "Launch executable (with args)",
                    type = "codelldb",
                    request = "launch",
                    program = pick_program,
                    cwd = "${workspaceFolder}",
                    stopOnEntry = false,
                    args = function()
                        local input = vim.fn.input({ prompt = "Arguments: " })
                        return vim.split(input, " ", { trimempty = true })
                    end,
                },
                {
                    name = "Attach to process",
                    type = "codelldb",
                    request = "attach",
                    pid = require("dap.utils").pick_process,
                    cwd = "${workspaceFolder}",
                },
            }

            dap.configurations.c = cpp_configs
            dap.configurations.cpp = cpp_configs
            dap.configurations.objc = cpp_configs
            dap.configurations.objcpp = cpp_configs

            -- =============================================
            -- Python (debugpy)
            -- =============================================
            dap.adapters.python = function(on_adapter)
                on_adapter({
                    type = "executable",
                    command = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python",
                    args = { "-m", "debugpy.adapter" },
                })
            end

            dap.configurations.python = {
                {
                    name = "Launch current file",
                    type = "python",
                    request = "launch",
                    program = "${file}",
                    cwd = "${workspaceFolder}",
                    console = "integratedTerminal",
                    -- the project's virtualenv if there is one
                    pythonPath = function() return require("core.run").python() end,
                },
            }
        end,
    },
}
