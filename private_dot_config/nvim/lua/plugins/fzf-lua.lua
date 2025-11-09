return {
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
    keys = {
      { "<leader>:", "<cmd>FzfLua command_history<cr>", desc = "Command History (fzf-lua)" },
      { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Files (fzf-lua)" },
      { "<leader>fs", "<cmd>FzfLua live_grep<cr>", desc = "Search (fzf-lua)" },
    },
  },
}
