local enabled = false
return {
  {'hrsh7th/cmp-nvim-lsp', enabled = enabled},
  {'hrsh7th/cmp-buffer', enabled = enabled},
  {'hrsh7th/cmp-path', enabled = enabled},
  {'hrsh7th/cmp-cmdline', enabled = enabled},
  {
    'hrsh7th/nvim-cmp',
    enabled = enabled,
    config = function()
      local lspkindicons = {
          Text = "",
          Method = "",
          Function = "",
          Constructor = "",
          Field = "",
          Variable = "",
          Class = "ﴯ",
          Interface = "",
          Module = "",
          Property = "ﰠ",
          Unit = "",
          Value = "",
          Enum = "",
          Keyword = "",
          Snippet = "",
          Color = "",
          File = "",
          Reference = "",
          Folder = "",
          EnumMember = "",
          Constant = "",
          Struct = "",
          Event = "",
          Operator = "",
          TypeParameter = "",
      }
      local cmp = require 'cmp'
      cmp.setup {
        snippet = {
          expand = function(args)
            vim.fn["vsnip#anonymous"](args.body) -- For `ultisnips` users.
          end,
        },
        mapping = {
          ['<C-k>'] = cmp.mapping.select_prev_item(),
          ['<C-j>'] = cmp.mapping.select_next_item(),
          ['<C-d>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.close(),
          ['<CR>'] = cmp.mapping.confirm {
            behavior = cmp.ConfirmBehavior.Replace,
            select = true,
          },
        },
        formatting = {
          format = function(entry, vim_item)
            vim_item.kind = string.format(
              "%s %s",
              lspkindicons[vim_item.kind],
              vim_item.kind
            )
            return vim_item
          end,
        },
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'vsnip' },
          --{ name = 'ultisnips' },
        }, {
          { name = 'buffer' },
        })
      }
    end
  },
}
