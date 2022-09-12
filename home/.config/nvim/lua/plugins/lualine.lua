-- Lualine
require('lualine').setup({ 
  options = { 
    transparent = true,
    theme = 'catppuccin'
  },
  sections = {
    lualine_b = {'diff', 'diagnostics'},
  }
})
