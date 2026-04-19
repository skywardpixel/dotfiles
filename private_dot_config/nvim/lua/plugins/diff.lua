return {
  {
    "mhinz/vim-signify",
    opts = {
      -- A small `updatetime` is preferred to update signs as files are updated
      -- The default `updatetime` is 4000
      updatetime = 500,
      -- Uses the previous commit rev to diff instead of current changes in fig
      use_prev_commit_rev = false,
    },
    keys = {
      { "[c", "<Plug>(signify-prev-hunk)", desc = "Goto previous hunk" },
      { "]c", "<Plug>(signify-next-hunk)", desc = "Goto next hunk" },
      { "[C", "<cmd>normal 9999[c<cr>", desc = "Goto first hunk" },
      { "]C", "<cmd>normal 9999]c<cr>", desc = "Goto last hunk" },
      { "ic", "<Plug>(signify-motion-inner-pending)", desc = "Hunk text object", mode = "o" },
      { "ic", "<Plug>(signify-motion-inner-visual)", desc = "Hunk text object", mode = "x" },
      { "ac", "<Plug>(signify-motion-outer-pending)", desc = "Hunk text object", mode = "o" },
      { "ac", "<Plug>(signify-motion-outer-pending)", desc = "Hunk text object", mode = "x" },
    },
    init = function()
      vim.g.signify_sign_add = "┃"
      vim.g.signify_sign_change = "┃"
      vim.g.signify_sign_change_delete = "~"
      vim.g.signify_sign_delete = "▁"
      vim.g.signify_sign_delete_first_line = "▔"
      vim.g.signify_sign_show_count = false
    end,
  },
}
