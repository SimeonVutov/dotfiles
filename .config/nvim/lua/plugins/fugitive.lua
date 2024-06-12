return {
    'tpope/vim-fugitive',
    keys = {
        {
            "<leader>gs",
            vim.cmd.Git,
            remap = true,
            mode = 'n'
        }
    }
}
