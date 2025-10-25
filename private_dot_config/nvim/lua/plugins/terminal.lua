return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      hidden = false,
      auto_scroll = true,
      persist_size = true,
    },
    keys = {
      { "<esc>",      "<c-\\><c-n>",                                                       mode = "t" },
      { "<c-w>",      "<c-\\><c-n><c-w>",                                                  mode = "t" },
      { "<leader>tv", "<cmd>lua require('toggleterm.terminal').Terminal:new({direction='vertical'}):open()<cr>", desc = "Open terminal (vertical)" },
      { "<leader>tt", "<cmd>lua require('toggleterm.terminal').Terminal:new():open()<cr>", desc = "Open terminal" },
    },
  },
}
