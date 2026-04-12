return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
  },

  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    init = function()
      -- Disable entire built-in ftplugin mappings to avoid conflicts.
      -- See https://github.com/neovim/neovim/tree/master/runtime/ftplugin for built-in ftplugins.
      vim.g.no_plugin_maps = true

      -- Or, disable per filetype (add as you like)
      -- vim.g.no_python_maps = true
      -- vim.g.no_ruby_maps = true
      -- vim.g.no_rust_maps = true
      -- vim.g.no_go_maps = true
    end,
    config = function()
      -- put your config here
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-context",
  },

  {
    "nvim-mini/mini.ai",
    version = false,
    opts = function()
      local gen_spec = require("mini.ai").gen_spec
      return {
        n_lines = 500,
        custom_textobjects = {
          o = gen_spec.treesitter({ -- code block
            a = { "@block.outer", "@conditional.outer", "@loop.outer" },
            i = { "@block.inner", "@conditional.inner", "@loop.inner" },
          }),
          f = gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }), -- function
          c = gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),       -- class
          u = gen_spec.function_call(),                                              -- u for "Usage"
          U = gen_spec.function_call({ name_pattern = "[%w_]" }),                    -- without dot in function name
        },
      }
    end,
  },
}