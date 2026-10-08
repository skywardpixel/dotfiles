return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
  },

  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    init = function()
      vim.g.no_plugin_maps = true
    end,
    opts = {},
  },

  {
    "nvim-treesitter/nvim-treesitter-context",
    opts = {},
  },
}
