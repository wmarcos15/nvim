-- lua/core/run.lua
--
-- <leader>rr (run) and <leader>rb (build) for the current file's language.
-- Output goes to a terminal split at the bottom; press q there to close it.
--
--   C / C++    CMake project: cmake --build build, then ./build/main
--              (or ./build/<project folder name>). No CMakeLists.txt:
--              compiles the single file and runs it.
--   Python     the project's .venv (or $VIRTUAL_ENV) if there is one, else python3
--   JS         node <file>
--   TS         npx tsx <file>
--   Java       java <file>   (single-file source launch)
local M = {}

local esc = vim.fn.shellescape

local function open_terminal(cmd, cwd)
    vim.cmd("botright 12new")
    local buf = vim.api.nvim_get_current_buf()
    vim.fn.jobstart(cmd, { term = true, cwd = cwd })
    vim.keymap.set("n", "q", "<cmd>bdelete!<cr>", { buffer = buf, silent = true, desc = "Close terminal" })
    vim.cmd("normal! G")
end

local function file() return vim.api.nvim_buf_get_name(0) end

-- C / C++ ────────────────────────────────────────────────────────────────
local function cmake_root() return vim.fs.root(0, { "CMakeLists.txt" }) end

local function single_file_binary()
    local dir = vim.fn.stdpath("cache") .. "/run"
    vim.fn.mkdir(dir, "p")
    return dir .. "/" .. vim.fn.fnamemodify(file(), ":t:r")
end

local function c_build_cmd()
    local root = cmake_root()
    if root then
        local configure = ""
        if not vim.uv.fs_stat(root .. "/build") then
            configure = "cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON && "
        end
        return configure .. "cmake --build build", root
    end
    local compiler = vim.bo.filetype == "c" and "cc -std=c17" or "c++ -std=c++20"
    return ("%s -g -Wall -Wextra %s -o %s"):format(compiler, esc(file()), esc(single_file_binary())),
        vim.fn.fnamemodify(file(), ":h")
end

local function c_run_cmd()
    local build, cwd = c_build_cmd()
    local root = cmake_root()
    if not root then return build .. " && " .. esc(single_file_binary()), cwd end
    local name = vim.fn.fnamemodify(root, ":t")
    return ("%s && if [ -x build/main ]; then ./build/main; else ./build/%s; fi"):format(build, esc(name)), root
end

-- Python ─────────────────────────────────────────────────────────────────
function M.python()
    local venv = vim.env.VIRTUAL_ENV
    if venv and vim.uv.fs_stat(venv .. "/bin/python") then return venv .. "/bin/python" end
    local root = vim.fs.root(0, { ".venv", "venv" })
    for _, dir in ipairs({ ".venv", "venv" }) do
        if root and vim.uv.fs_stat(root .. "/" .. dir .. "/bin/python") then
            return root .. "/" .. dir .. "/bin/python"
        end
    end
    return "python3"
end

local function here() return vim.fn.fnamemodify(file(), ":h") end

local runners = {
    c = { build = c_build_cmd, run = c_run_cmd },
    cpp = { build = c_build_cmd, run = c_run_cmd },
    python = { run = function() return esc(M.python()) .. " " .. esc(file()), here() end },
    javascript = { run = function() return "node " .. esc(file()), here() end },
    typescript = { run = function() return "npx --yes tsx " .. esc(file()), here() end },
    java = { run = function() return "java " .. esc(file()), here() end },
}

local function go(action)
    local runner = runners[vim.bo.filetype]
    if not runner or not runner[action] then
        vim.notify(("No %s command for filetype '%s' (see lua/core/run.lua)"):format(action, vim.bo.filetype),
            vim.log.levels.WARN)
        return
    end
    vim.cmd("silent! update")
    local cmd, cwd = runner[action]()
    open_terminal(cmd, cwd)
end

function M.run() go("run") end
function M.build() go("build") end

return M
