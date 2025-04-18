return {
    "folke/snacks.nvim",
    priority = 1000,
    -- lazy = true,
    -- -@type snacks.Config
    opts = {
        bigfile = {
            notify = true,
            size = 5 * 1024 * 1024, -- 5MB
            line_length = 1000, -- average line length (useful for minified files)
            -- Enable or disable features when big file detected
            ---@param ctx {buf: number, ft:string}
            setup = function(ctx)
                if vim.fn.exists(":NoMatchParen") ~= 0 then
                    vim.cmd([[NoMatchParen]])
                end
                Snacks.util.wo(0, { foldmethod = "manual", statuscolumn = "", conceallevel = 0 })
                vim.b.minianimate_disable = true
                vim.schedule(function()
                    if vim.api.nvim_buf_is_valid(ctx.buf) then
                        vim.bo[ctx.buf].syntax = ctx.ft
                    end
                end)
            end,
        },
        image = { enabled = true },
        indent = {
            animate = {
                enabled = vim.fn.has("nvim-0.10") == 1,
                style = "out",
                easing = "linear",
                duration = {
                    step = 100, -- ms per step
                    total = 200, -- maximum duration
                },
            },
        },
        quickfile = { enabled = true },
        scroll = { enabled = true },
    },
}
