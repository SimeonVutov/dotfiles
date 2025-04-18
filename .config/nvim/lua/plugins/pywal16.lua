return {
    'uZer/pywal16.nvim',
    -- priority=1000,
    lazy=true,
    config = function()
        local color = 'pywal16'
        vim.cmd.colorscheme(color)
    end,
}
