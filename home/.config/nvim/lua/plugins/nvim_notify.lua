return {
  'rcarriga/nvim-notify',
  config = function ()
    require("notify").setup {
      background_colour = "FloatShadow",
      timeout = 3000,
      stages = "static",
      animate = false,
      max_height = function()
        return math.floor(vim.o.lines * 0.75)
      end,
      max_width = function()
        return math.floor(vim.o.lines * 2)
      end,
      on_open = function(win)
        vim.api.nvim_win_set_config(win, { zindex = 100 })
      end,
    }
    vim.notify = require('notify')
  end
}
