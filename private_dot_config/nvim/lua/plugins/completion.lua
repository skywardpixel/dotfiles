return {
  {
    "nvim-mini/mini.completion",
    version = "*",
    opts = {},
    config = function(_, opts)
      require("mini.completion").setup(opts)
      -- Disable mini.completion in Snacks picker
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "snacks_picker_input",
        desc = "Disable mini.completion for Snacks picker",
        group = vim.api.nvim_create_augroup("user_mini", {}),
        command = "lua vim.b.minicompletion_disable=true",
      })
    end,
  },
}
