return {
    'williamboman/mason.nvim',
    dependencies = {
        'williamboman/mason-lspconfig.nvim',
        'WhoIsSethDaniel/mason-tool-installer.nvim',
    },
    config = function()
        local mason = require('mason')

        local mason_lspconfig = require('mason-lspconfig')

        local mason_tool_installer = require('mason-tool-installer')

        mason.setup({
            ui = {
                icons = {
                    package_installed = '✓',
                    package_pending = '➜',
                    package_uninstalled = '✗',
                },
            },
        })

        mason_lspconfig.setup({
            ensure_installed = {
                'html',
                'cssls',
                'lua_ls',
                'clangd',
                'emmet_language_server',
                'eslint',
                'jdtls',
                'jsonls',
                'pyright',
                'sqlls'
            },
        })

        mason_tool_installer.setup({
            ensure_installed = {
                'stylua', -- lua formatter
                'eslint_d',
                'flake8',
            },
        })
    end,
}
