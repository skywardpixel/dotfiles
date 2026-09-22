local lsps = { "stylua", "lua_ls", "clangd", "pyright", "gopls" }

local function default_root(name)
  return function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    -- Fallback to basic VCS markers if the LSP doesn't have root_markers defined
    local markers = vim.lsp.config[name].root_markers or { ".git", ".hg", ".jj" }
    local root = vim.fs.root(bufnr, markers)
    on_dir(root or vim.fn.getcwd())
  end
end

for _, name in ipairs(lsps) do
  vim.lsp.config[name] = { root_dir = default_root(name) }
end
vim.lsp.enable(lsps)
