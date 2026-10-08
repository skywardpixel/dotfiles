-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Auto read/write
vim.opt.autoread = true
vim.opt.autowrite = true

-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true

-- Search options
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Hide mode since the statusline shows it
vim.opt.showmode = false

-- Confirm to save changes before exiting modified buffer
vim.opt.confirm = true

-- Indent options
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.smartindent = true
vim.opt.breakindent = true

-- Scroll options
vim.opt.scrolloff = 4
vim.opt.sidescrolloff = 8
vim.opt.smoothscroll = true

-- Show inline diagnostics
vim.diagnostic.config({
  virtual_text = false,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "",
      [vim.diagnostic.severity.WARN] = "",
      [vim.diagnostic.severity.INFO] = "",
      [vim.diagnostic.severity.HINT] = "",
    },
  },
})
