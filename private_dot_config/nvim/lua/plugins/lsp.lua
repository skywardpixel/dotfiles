return {
  {
    "neovim/nvim-lspconfig",
    keys = {
      {
        "gD",
        "<cmd>lua vim.lsp.buf.declaration()<cr>",
        desc = "Goto declaration"
      },
      {
        "gW",
        "<cmd>lua vim.lsp.buf.workspace_symbol()<cr>",
        desc = "Search for workspace symbol"
      },
      {
        "K",
        "<cmd>lua vim.lsp.buf.hover()<cr>",
        desc = "LSP hover",
      },
      {
        "grn",
        "<cmd>lua vim.lsp.buf.rename()<cr>",
        desc = "Rename word under cursor",
      },
      {
        "gra",
        "<cmd>lua vim.lsp.buf.code_action()<cr>",
        desc = "Code Actions",
        mode = { "n", "v" }
      },
      {
        "gd",
        "<cmd>lua vim.lsp.buf.definition()<cr>",
        desc = "Goto definition",
      },
      {
        "gri",
        "<cmd>lua vim.lsp.buf.implementation()<cr>",
        desc = "Goto implementation",
      },
      {
        "grr",
        "<cmd>lua vim.lsp.buf.references()<cr>",
        desc = "Show references",
      },
      {
        "[d",
        "<cmd>lua if vim.diagnostic.jump then vim.diagnostic.jump()(-1) else vim.diagnostic.goto_prev() end<cr>",
        desc = "Goto previous diagnostic",
      },
      {
        "]d",
        "<cmd>lua if vim.diagnostic.jump then vim.diagnostic.jump()(1) else vim.diagnostic.goto_next() end<cr>",
        desc = "Goto next diagnostic",
      },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    opts = {},
  },

  {
    'saghen/blink.cmp',
    -- optional: provides snippets for the snippet source
    dependencies = { 'rafamadriz/friendly-snippets' },

    -- use a release tag to download pre-built binaries
    version = '1.*',
    -- AND/OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
    -- build = 'cargo build --release',
    -- If you use nix, you can build from source using latest nightly rust with:
    -- build = 'nix run .#build-plugin',

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      -- 'default' (recommended) for mappings similar to built-in completions (C-y to accept)
      -- 'super-tab' for mappings similar to vscode (tab to accept)
      -- 'enter' for enter to accept
      -- 'none' for no mappings
      --
      -- All presets have the following mappings:
      -- C-space: Open menu or open docs if already open
      -- C-n/C-p or Up/Down: Select next/previous item
      -- C-e: Hide menu
      -- C-k: Toggle signature help (if signature.enabled = true)
      --
      -- See :h blink-cmp-config-keymap for defining your own keymap
      keymap = { preset = 'default' },

      appearance = {
        -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
        -- Adjusts spacing to ensure icons are aligned
        nerd_font_variant = 'normal'
      },

      -- (Default) Only show the documentation popup when manually triggered
      completion = { documentation = { auto_show = false } },

      -- Default list of enabled providers defined so that you can extend it
      -- elsewhere in your config, without redefining it, due to `opts_extend`
      sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer' },
      },

      -- (Default) Rust fuzzy matcher for typo resistance and significantly better performance
      -- You may use a lua implementation instead by using `implementation = "lua"` or fallback to the lua implementation,
      -- when the Rust fuzzy matcher is not available, by using `implementation = "prefer_rust"`
      --
      -- See the fuzzy documentation for more information
      fuzzy = { implementation = "prefer_rust_with_warning" }
    },
    opts_extend = { "sources.default" },
  },

  {
    "folke/trouble.nvim",
    opts = {},
    cmd = "Trouble",
    keys = {
      {
        "<leader>xx",
        "<cmd>Trouble diagnostics toggle<cr>",
        desc = "Diagnostics (Trouble)",
      },
      {
        "<leader>xX",
        "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
        desc = "Buffer Diagnostics (Trouble)",
      },
      {
        "<leader>cs",
        "<cmd>Trouble symbols toggle focus=false<cr>",
        desc = "Symbols (Trouble)",
      },
      {
        "<leader>cl",
        "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
        desc = "LSP Definitions / references / ... (Trouble)",
      },
      {
        "<leader>xL",
        "<cmd>Trouble loclist toggle<cr>",
        desc = "Location List (Trouble)",
      },
      {
        "<leader>xQ",
        "<cmd>Trouble qflist toggle<cr>",
        desc = "Quickfix List (Trouble)",
      },
    },
  },
}
