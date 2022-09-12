local M = {}

M.init = function(use)
  -- colorscheme
  use {
    'catppuccin/nvim',
    as = 'catppuccin',
    config = function()
      require('catppuccin').setup()
    end
  }
  vim.g.catppuccin_flavour = "macchiato"
  vim.cmd[[colorscheme catppuccin]]
end

return M
