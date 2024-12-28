return {
    'uZer/pywal16.nvim',
    priority=1000,
    config = function()
        local color = color or 'pywal16'
        vim.cmd.colorscheme(color)
    end,
}
