return {
  'rcarriga/nvim-notify',
  config = function ()
    require("notify").setup {
      animate = false,
      stages = 'static',
    }
    vim.notify = require('notify')
  end
}
