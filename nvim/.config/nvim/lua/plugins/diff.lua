return {
  {
    "nvim-mini/mini.diff",
    version = "*",
    opts = {
      view = {
        style = "sign",
        signs = {
          add = "▎",
          change = "▎",
          delete = "",
        },
      },
    },
  },

  {
    "nvim-mini/mini.diff",
    config = function(_, opts)
      require("mini.diff").setup(opts)
      Snacks.toggle({
        name = "Mini Diff Signs",
        get = function() return vim.g.minidiff_disable ~= true end,
        set = function(state)
          vim.g.minidiff_disable = not state
          if state then
            require("mini.diff").enable(0)
          else
            require("mini.diff").disable(0)
          end
          -- HACK: redraw to update the signs
          vim.defer_fn(function() vim.cmd([[redraw!]]) end, 200)
        end,
      }):map("<leader>uG")
      vim.keymap.set("n", "<leader>vo", function()
        ---@diagnostic disable-next-line: missing-parameter
        MiniDiff.toggle_overlay()
      end, { desc = "Diff Overlay" })
    end,
  },
}
