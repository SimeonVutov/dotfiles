return {
    "nvim-lualine/lualine.nvim",
    event='VeryLazy',
    dependencies = {
        "nvim-tree/nvim-web-devicons",
        "Alexis12119/nightly.nvim",
    },
    opts = {
        options = {
            icons_enabled = true,
            theme = 'nightly',
            component_separators = { left = '', right = ''},
            section_separators = { left = '', right = ''},
            section_background = 'rgba:0,0,0,0',
            disabled_filetypes = {
                statusline = {},
                winbar = {},
            },
            ignore_focus = {},
            always_divide_middle = true,
            globalstatus = false,
            refresh = {
                statusline = 100,
                tabline = 100,
                winbar = 100,
            }
        },
        sections = {
            lualine_a = {'mode'},
            lualine_b = {'branch', 'diff', 'diagnostics'},
            lualine_c = {'filename'},
            lualine_x = {'encoding', 'fileformat', 'filetype'},
            lualine_y = {'progress'},
            lualine_z = {'location'}
        },
        inactive_sections = {
            lualine_a = {},
            lualine_b = {},
            lualine_c = {'filename'},
            lualine_x = {'location'},
            lualine_y = {},
            lualine_z = {}
        },
        tabline = {},
        winbar = {},
        inactive_winbar = {},
        extensions = {}
    },
}
