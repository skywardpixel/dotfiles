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
  }
}
