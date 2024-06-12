return {
        'EdenEast/nightfox.nvim',
        as = 'nightfox',
        priority = 1000,
        init=function ()
            local color = color or 'carbonfox'
            vim.cmd.colorscheme(color)
        end
}
