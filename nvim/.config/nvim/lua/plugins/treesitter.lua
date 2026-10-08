return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {
          "c", "cpp", "go", "html", "java", "json", "kotlin", "lua",
          "objc", "toml", "typescript", "yaml", "zsh",
        },
        desc = "Start treesitter highlighting",
        group = vim.api.nvim_create_augroup("user_treesitter", {}),
        callback = function(ev) pcall(vim.treesitter.start, ev.buf) end,
      })
    end,
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
