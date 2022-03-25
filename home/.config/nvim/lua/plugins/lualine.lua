-- Lualine
require('lualine').setup({ 
  options = { transparent = true },
  sections = {
    lualine_b = {'diff', 'diagnostics'},
  }
})
