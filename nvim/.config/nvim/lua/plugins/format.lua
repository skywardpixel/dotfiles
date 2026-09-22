return {
  {
    "nmac427/guess-indent.nvim",
    opts = {},
  },

  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>cF",
        function() require("conform").format({ async = true }) end,
        mode = "",
        desc = "Format buffer",
      },
    },
    ---@module "conform"
    ---@type conform.setupOpts
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "isort", "black" },
      },
      default_format_opts = {
        lsp_format = "fallback",
      },
      formatters = {
        shfmt = {
          append_args = { "-i", "2" },
        },
      },
    },
  },
}
