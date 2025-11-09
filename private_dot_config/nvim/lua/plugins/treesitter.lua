return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = true,
    opts = {
      ensure_installed = {
        "markdown",
        "markdown_inline",
        "diff",
      },
      sync_install = true,
      auto_install = true,
      highlight = { enable = false },
      indent = { enable = false },
    },
    config = function(_, opts)
      -- Try calling old setup function in case user has older version of nvim-treesitter.
      local ts_main, ts_configs = pcall(function() return require("nvim-treesitter.configs") end)
      if ts_main and ts_configs and ts_configs.setup then
        ts_configs.setup(opts)
      else
        -- Try calling the updated location of the setup.
        local treesitter = require("nvim-treesitter")
        if treesitter.setup then
          treesitter.setup(opts)
        end
        -- Handle auto installing parsers since new nvim-treesitter does not.
        if treesitter.install and opts.auto_install then
          if opts.sync_install then
            treesitter.install(opts.ensure_installed):wait(500)
          else
            treesitter.install(opts.ensure_installed)
          end
        end
      end
    end
  },
}
