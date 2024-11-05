return {
  'nvim-treesitter/nvim-treesitter',
  event = 'CursorHold',
  run = ':TSUpdate',
  --run = function()
  --    local ts_update = require('nvim-treesitter.install').update({ with_sync = true })
  --    ts_update()
  --end,
  config = function()
    require'nvim-treesitter.configs'.setup {
      ensure_installed = "all", -- one of "all", "maintained" (parsers with maintainers), or a list of languages
      highlight = {
        enable = true,
        custom_captures = {
          ["ff"] = "Function",
        },
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "gnn",
          node_incremental = "grn",
          scope_incremental = "grc",
          node_decremental = "grm",
        },
      },
      indent = {
        enabled = true,
      },
      -- nvim-ts-autotag
      autotag = {
        enable = true,
      },
    }
  end
}
