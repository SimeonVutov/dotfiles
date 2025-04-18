local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)
require("lazy").setup({
  spec = {
    { import = "plugins" },
    { import = "plugins.lsp" },
    -- { import = "plugins.debugging" },
  },
  defaults = {
    lazy = false,
  },
  checker = {
    enabled = true,
    notify = false
  },
  performance = {
    cache = { enabled = true }, -- Enable caching to improve startup speed
    reset_packpath = true, -- Clean packpath to prevent conflicts
    rtp = {
      reset = true, -- Ensure clean runtime path
      disabled_plugins = { -- Disable unused built-in plugins
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
        "netrwPlugin",
        "matchit",
        "matchparen",
        "rplugin", -- Remote plugins (not needed if not using :UpdateRemotePlugins)
      },
    },
  },
  ui = {
    border = "none", -- Faster UI rendering
  },
})
