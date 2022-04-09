vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.termguicolors = true

-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true

-- Search options
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Hide mode since we have lualine
vim.opt.showmode = false

-- Confirm to save changes before exiting modified buffer
vim.opt.confirm = true

-- Indent options
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.smarttab = true
vim.opt.smartindent = true
vim.opt.autoindent = true
vim.opt.breakindent = true

-- Scroll options
vim.opt.scrolloff = 4
vim.opt.sidescrolloff = 8
vim.opt.smoothscroll = true
