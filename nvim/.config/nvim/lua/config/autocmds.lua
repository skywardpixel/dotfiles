-- Treesitter highlighting, as recommended by nvim-treesitter's README.
vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "c", "cpp", "go", "html", "java", "json", "kotlin", "lua",
    "objc", "toml", "typescript", "yaml", "zsh",
  },
  callback = function() vim.treesitter.start() end,
})
