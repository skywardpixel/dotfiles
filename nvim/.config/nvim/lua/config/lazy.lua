-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim
local plugins_spec = {
  { import = "plugins" },
}

-- Only import google-plugins if the directory exists (stowed via google-nvim)
local google_plugins_dir = vim.fn.stdpath("config") .. "/lua/google-plugins"
if vim.uv.fs_stat(google_plugins_dir) then
  table.insert(plugins_spec, { import = "google-plugins" })
end

require("lazy").setup({
  spec = plugins_spec,
  -- Colorscheme used while installing plugins.
  install = { colorscheme = { "tokyonight" } },
})
