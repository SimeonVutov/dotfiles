return {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
        -- add any options here
    },
    dependencies = {
        -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
        "MunifTanjim/nui.nvim",
        -- OPTIONAL:
        --   `nvim-notify` is only needed, if you want to use the notification view.
        --   If not available, we use `mini` as the fallback
        {
            "rcarriga/nvim-notify",
            config = function()
                local pywal_colors = require("pywal16.core") -- Correct module for pywal16 colors
                local background_color = pywal_colors.background or "#000000" -- Fallback to black if not found

                require("notify").setup({
                    background_colour = background_color,
                    stages = "fade_in_slide_out", -- Optional: Animation style
                    timeout = 3000, -- Optional: Notification duration
                    fps = 120, -- Optional: Smoothness of animations
                    border = {
                        style = "rounded", -- Border style (rounded, solid, single, etc.)
                        color = border_color, -- Pywal color for border
                    },
                })
            end,
        }
    }
}
