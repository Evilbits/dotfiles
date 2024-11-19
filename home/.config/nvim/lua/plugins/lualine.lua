return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function(_, opts) 
    -- define function and formatting of the information
    -- local function parrot_status()
    --   local status_info = require("parrot.config").get_status_info()
    --   local status = ""
    --   if status_info.is_chat then
    --     status = status_info.prov.chat.name
    --   else
    --     status = status_info.prov.command.name
    --   end
    --   return string.format("%s(%s)", status, status_info.model)
    -- end

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
  end
}
