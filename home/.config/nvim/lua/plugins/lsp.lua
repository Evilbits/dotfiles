return {
  -- LSP configuration
  {'neovim/nvim-lspconfig'},
  -- LSP installer
  {'williamboman/nvim-lsp-installer'},
  -- Development icons
  {'kyazdani42/nvim-web-devicons'},
  -- lspconfig
  {
    "neovim/nvim-lspconfig",
    dependencies = { 'saghen/blink.cmp', 'ray-x/lsp_signature.nvim' },
    config = function(_, opts)
      local lspconfig = require('lspconfig')
      local servers = { 'pylsp', 'ts_ls' }

      local on_attach = function(client, bufnr)
        -- Add any attach functionality here
        local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
        local opts = { noremap=true, silent=true }
      end

      for _, config in pairs(servers) do
        capabilities = require('blink.cmp').get_lsp_capabilities(config.capabilities)
        lspconfig[config].setup {
          on_attach = on_attach,
          capabilities = capabilities,
          flags = {
            debounce_text_changes = 150,
          }
        }
      end

      lspconfig.pylsp.setup {
        settings = {
            pylsp = {
              plugins = {
                  -- formatter options
                  black = { enabled = true },
                  -- type checker
                  pylsp_mypy = { enabled = true },
                  -- auto-completion options
                  jedi_completion = { fuzzy = true },
                  -- -- import sorting
                  pyls_isort = { enabled = true },
              },
            },
        },
      }
    end
  }
}
