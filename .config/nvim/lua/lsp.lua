return {
		'VonHeikemen/lsp-zero.nvim',
		branch = 'v3.x',
		dependencies = {
			{
                'williamboman/mason.nvim',
            },
			{'williamboman/mason-lspconfig.nvim'},
            {'WhoIsSethDaniel/mason-tool-installer.nvim'},

            -- LSP Support
            {'neovim/nvim-lspconfig'},
            -- Autocompletion
            {'hrsh7th/nvim-cmp'},
            {'hrsh7th/cmp-nvim-lsp'},
            {'L3MON4D3/LuaSnip'},
        },
        keys = {
            {
                'lr', function() vim.lsp.buf.references() end, mode = 'n'
            },
            {
                '<leader>vws', function() vim.lsp.buf.workspace_symbol() end, mode = 'n'
            },
            {
                '<leader>vd', function() vim.diagnostic.open_float() end, mode = 'n'
            },
            {
                '<leader>vd', function() vim.diagnostic.open_float() end, mode = 'n'
            },
            {
                '<leader>vca', function() vim.lsp.buf.code_action() end, mode = 'n'
            },
            {
                '<leader>vrr', function() vim.lsp.buf.references() end, mode = 'n'
            },
            {
                '<leader>vrn', function() vim.lsp.buf.rename() end, mode = 'n'
            },
            {
                '<C-h>', function() vim.lsp.buf.signature_help() end, mode = 'i'
            }
        },
        init = function()
            local lsp_zero = require('lsp-zero')
            lsp_zero.on_attach(function(client, bufnr)
                lsp_zero.default_keymaps({
	                buffer = bufnr,
	                exclude = {'gr'}
                })
            end)

            require('mason').setup({})
            require('mason-lspconfig').setup({
                ensure_installed = {
                    'clangd',
                    'emmet_language_server',
                    'eslint',
                    'html',
                    'jdtls',
                    'jsonls',
                    'lua_ls',
                    'pyright',
                    'sqlls'
                },
                handlers = {
                    lsp_zero.default_setup,
                }
            })
            require('mason-tool-installer').setup({
                ensure_installed = {
                    'flake8',
                    'eslint_d',
                }
            })
        end
}
