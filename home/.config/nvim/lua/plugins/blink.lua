return {
  'saghen/blink.cmp',
  enabled = true,
  lazy = false, -- lazy loading handled internally
  dependencies = 'rafamadriz/friendly-snippets',
  -- use a release tag to download pre-built binaries
  version = 'v0.*',

  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    -- 'default' for mappings similar to built-in completion
    -- 'super-tab' for mappings similar to vscode (tab to accept, arrow keys to navigate)
    -- 'enter' for mappings similar to 'super-tab' but with 'enter' to accept
    -- see the "default configuration" section below for full documentation on how to define
    -- your own keymap.
    keymap = {
      preset    = 'default',
      ['<C-k>'] = { 'select_prev', 'fallback' },
      ['<C-j>'] = { 'select_next', 'fallback' },
      ['<CR>']  = { 'select_and_accept', 'fallback' },
    },
    completion = {
      accept = {
        auto_brackets = {
          enabled = true,
        },
      },
      list = {
        --selection = 'auto_insert'
        selection = 'preselect'
      },
      menu = {
        border = 'single',
        draw = {
          treesitter = true,
          components = {
            label_description = {
              width = { min = 20, max = 20 },
              text = function(ctx) return ctx.label_description end,
              highlight = 'BlinkCmpLabelDescription',
            },
          },
        },
      },
      documentation = {
        auto_show = true,
        window = {
          border = 'single',
        },
      },
    },
  },
  signature = {
    enabled = true
  }
}
