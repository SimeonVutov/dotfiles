return {
    "mfussenegger/nvim-dap-python",
    config = function()
        local dap = require('dap')

        local mason_path = vim.fn.glob(vim.fn.stdpath "data" .. "/mason/")
        local debugpy_path = mason_path .. "packages/debugpy/debugpy"
        pcall(function()
            require("dap-python").setup(mason_path .. "packages/debugpy/venv/bin/python")
        end)

        dap.adapters.python = {
            type = 'executable',
            command = mason_path .. 'packages/debugpy/venv/bin/python',
            args = { '-m', 'debugpy.adapter' },
        }

        -- if vim.v.shell_error == 0 then
        -- require("dap-python").setup("/usr/bin/python3") -- XXX: Replace this with your preferred Python, if wanted
        -- An example configuration to launch any Python file, via debugpy
        dap.configurations.python = {
            {
                type = "python",
                request = "launch",
                name = "Launch Via debugpy",
                program = "${file}",
                python = function()
                    return '/usr/bin/python'
                end,
                host = 'localhost',
                port = 5678,
                -- ... more options, see https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings
            },
        }
    end,
    dependencies = {
        "mfussenegger/nvim-dap",
        "nvim-treesitter/nvim-treesitter",
    },
}
