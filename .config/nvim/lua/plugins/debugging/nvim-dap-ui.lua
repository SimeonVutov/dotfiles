return {
    "rcarriga/nvim-dap-ui",
    event = 'VeryLazy',
    config = function()
        local dap, dapui = require("dap"), require("dapui")
        dapui.setup()

        -- Note: Added this <leader>dd duplicate of <F5> because somehow the <F5>
        -- mapping keeps getting reset each time I restart nvim-dap. Annoying but whatever.
        --
        -- vim.keymap.set(
        -- "n",
        -- "<leader>dd",
        -- function()
        --     require("dapui").open()  -- Requires nvim-dap-ui

        --     vim.cmd[[DapContinue]]  -- Important: This will lazy-load nvim-dap
        -- end
        -- )

        dap.listeners.before.attach.dapui_config = function()
            dapui.open()
        end
        dap.listeners.before.launch.dapui_config = function()
            dapui.open()
        end
        dap.listeners.before.event_terminated.dapui_config = function()
            dapui.close()
        end
        dap.listeners.before.event_exited.dapui_config = function()
            dapui.close()
        end
    end,
    dependencies = {
        "mfussenegger/nvim-dap",
        "nvim-neotest/nvim-nio",
    },
}
