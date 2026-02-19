return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "macchiato",
        integrations = {
          treesitter = true,
        },
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },
  { "diegoulloao/neofusion.nvim", priority = 1000, config = true }
}

--local M = {}
--
--M.init = function(use)
--  -- colorscheme
--  use {
--    'catppuccin/nvim',
--    as = 'catppuccin',
--    config = function()
--      require('catppuccin').setup()
--    end
--  }
--  vim.g.catppuccin_flavour = "macchiato"
--  vim.cmd[[colorscheme catppuccin]]
--end
--
--return M
