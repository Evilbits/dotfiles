return {
  -- LSP installer
  {'williamboman/nvim-lsp-installer'},
  -- lspconfig
  {
    "neovim/nvim-lspconfig",
    dependencies = { 'saghen/blink.cmp', 'ray-x/lsp_signature.nvim' },
    config = function(_, _)
      local lspconfig = require('lspconfig')
      local servers = { 'pylsp', 'ts_ls', 'lua_ls', 'terraformls' }

      local on_attach = function(client, bufnr)
        require "lsp_signature".on_attach({
          hint = true
        }, bufnr)
        -- Add any attach functionality here
        local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
        local opts = { noremap=true, silent=true }
      end

      for _, config in pairs(servers) do
        capabilities = require('blink.cmp').get_lsp_capabilities(config.capabilities)
        lspconfig[config].setup {
          on_attach = on_attach,
          capabilities = capabilities,
          --flags = {
          --  debounce_text_changes = 150,
          --}
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

      -- Setup LSP for Nvim Lua 
      lspconfig.lua_ls.setup {
        on_init = function(client)
          if client.workspace_folders then
            local path = client.workspace_folders[1].name
            if vim.uv.fs_stat(path..'/.luarc.json') or vim.uv.fs_stat(path..'/.luarc.jsonc') then
              return
            end
          end
      
          client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
            runtime = {
              -- Tell the language server which version of Lua you're using
              -- (most likely LuaJIT in the case of Neovim)
              version = 'LuaJIT'
            },
            -- Make the server aware of Neovim runtime files
            workspace = {
              checkThirdParty = false,
              library = {
                vim.env.VIMRUNTIME
                -- Depending on the usage, you might want to add additional paths here.
                -- "${3rd}/luv/library"
                -- "${3rd}/busted/library",
              }
              -- or pull in all of 'runtimepath'. NOTE: this is a lot slower and will cause issues when working on your own configuration (see https://github.com/neovim/nvim-lspconfig/issues/3189)
              -- library = vim.api.nvim_get_runtime_file("", true)
            }
          })
        end,
        settings = {
          Lua = {}
        }
      }
    end
  }
}
