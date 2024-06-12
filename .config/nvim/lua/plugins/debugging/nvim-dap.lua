return {
    'mfussenegger/nvim-dap',
    event = 'VeryLazy',
    dependencies = {
        'rcarriga/nvim-dap-ui',
    },
    config = function()
        vim.keymap.set("n", "<F5>", "<Cmd>lua require'dap'.continue()<CR>")
        vim.keymap.set("n", "<F10>", "<Cmd>lua require'dap'.step_over()<CR>")
        vim.keymap.set("n", "<F11>", "<Cmd>lua require'dap'.step_into()<CR>")
        vim.keymap.set("n", "<F12>", "<Cmd>lua require'dap'.step_out()<CR>")
        vim.keymap.set("n", "<leader>bb", "<Cmd>lua require'dap'.toggle_breakpoint()<CR>")
        vim.keymap.set("n", "<leader>bB", "<Cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>")
        vim.keymap.set("n", "<leader>bL", "<Cmd>lua require'dap'.set_breakpoint(nil, nil, vim.fn.input('Log point message: '))<CR>")
        vim.keymap.set("n", "<leader>br", "<Cmd>lua require'dap'.repl.open()<CR>")
        vim.keymap.set("n", "<leader>bl", "<Cmd>lua require'dap'.run_last()<CR>")
        vim.keymap.set("n", "<leader>bT", "<Cmd>lua require'dap'.terminate()<CR>")
        vim.keymap.set("n", "<leader>bD", "<Cmd>lua require'dap'.disconnect()<CR> require'dap'.close()<CR>")
        vim.keymap.set("n", "<leader>bt", "<Cmd>lua require'dapui'.toggle()<CR>")
        vim.keymap.set("n", "<leader>be", "<Cmd>lua require'dapui'.eval()<CR>")
    end,
}
