return {
  'saghen/blink.cmp',
  enabled = true,
  lazy = false, -- lazy loading handled internally
  dependencies = 'rafamadriz/friendly-snippets',
  -- use a release tag to download pre-built binaries
  version = 'v0.*',

  opts = {
    keymap = {
      preset    = 'enter',
      ['<C-k>'] = { 'select_prev', 'fallback' },
      ['<C-j>'] = { 'select_next', 'fallback' },
      -- ['<CR>']  = { 'select_and_accept', 'fallback' },
    },
    completion = {
      accept = {
        auto_brackets = {
          enabled = true,
        },
      },
      list = {
        selection = {
          -- preselect = true,
          preselect = function(ctx) return ctx.mode ~= 'cmdline' end,
          auto_insert = function(ctx) return ctx.mode == 'cmdline' end,
        },
      },
      menu = {
        -- Don't show for cmdline
        border = 'single',
        draw = {
          treesitter = { 'lsp' },
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
