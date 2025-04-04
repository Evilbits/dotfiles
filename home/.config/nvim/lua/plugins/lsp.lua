return {
  -- LSP installer
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "BufEnter", -- Or `LspAttach`
    priority = 1000,    -- needs to be loaded in first
    config = function()
      require('tiny-inline-diagnostic').setup({
        options = {
          show_source = true,
          -- If multiple diagnostics are under the cursor, display all of them.
          multiple_diag_under_cursor = true,
          -- Enable diagnostic message on all lines.
          multilines = true,
        }
      })
      vim.diagnostic.config({ virtual_text = false, update_in_insert = true })
    end
  },
  -- Auto format on save
  {
    'stevearc/conform.nvim',
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          -- Conform will run multiple formatters sequentially
          python = { "ruff_fix", "ruff_format" }, -- { "isort", }
          -- Conform will run the first available formatter
          -- javascript = { "prettierd", "prettier", stop_after_first = true },
          javascript = { "prettierd", "prettier" },
          typescript = { "prettierd", "prettier" },
          javascriptreact = { "prettierd", "prettier" },
          typescriptreact = { "prettierd", "prettier" },
        },
        format_on_save = {
          -- These options will be passed to conform.format()
          timeout_ms = 1000,
          lsp_format = "fallback",
        },
      })
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { 'williamboman/mason.nvim' },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "pylsp", "ts_ls", "terraformls", "eslint" },
      })
    end,
  },
  -- lspconfig
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      'saghen/blink.cmp',
      'ray-x/lsp_signature.nvim',
      "williamboman/mason-lspconfig.nvim",
    },
    opts = {
      diagnostics = {
        virtual_text = false,
        update_in_insert = true,
      },
    },
    config = function(_, _)
      local lspconfig = require('lspconfig')
      --local servers = { 'pylsp', 'ts_ls', 'lua_ls', 'terraformls' }
      local capabilities = require('blink.cmp').get_lsp_capabilities()

      local on_attach = function(client, bufnr)
        local opts = { buffer = bufnr, remap = false }

        -- Setup Telescope keymaps that rely on an LSP attaching
        local builtin = require('telescope.builtin')
        vim.keymap.set('n', '<leader>gd', builtin.lsp_references, opts)
        vim.keymap.set('n', '<leader>gD', builtin.lsp_definitions, opts)
        vim.keymap.set('n', '<leader>gi', builtin.lsp_implementations, opts)
        vim.keymap.set('n', '<leader>gt', builtin.lsp_type_definitions, opts)
        vim.keymap.set("n", "<C-x>", vim.lsp.buf.hover, opts)

        -- require "lsp_signature".on_attach({
        --   hint = true
        -- }, bufnr)
        vim.diagnostic.config({ virtual_text = false, update_in_insert = true })
      end

      lspconfig.terraformls.setup {
        on_attach = on_attach,
        capabilities = capabilities,
      }
      lspconfig.ts_ls.setup {
        on_attach = on_attach,
        capabilities = capabilities,
      }
      lspconfig.eslint.setup {
        capabilities = capabilities,
        settings = {
          -- helps eslint find the eslintrc when it's placed in a subfolder
          workingDirectory = { mode = "auto" },
        },
        -- Run ESLint when you save the file
        on_attach = function(client, bufnr)
          vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = bufnr,
            command = "EslintFixAll",
          })

          -- Call your existing on_attach if you have one
          on_attach(client, bufnr)
        end,
      }
      lspconfig.gopls.setup {
        on_attach = on_attach,
        capabilities = capabilities,
      }

      lspconfig.pylsp.setup {
        on_attach = on_attach,
        settings = {
          pylsp = {
            plugins = {
              -- formatter options
              black = { enabled = true },
              -- type checker
              pylsp_mypy = {
                enabled = true,
              },
              -- Linter
              ruff = {
                enabled = true,
                -- formatEnabled = true,
                -- format = { "I" },
                executable = "ruff",
              },
              pylint = {
                enabled = false,
                executable = "pylint",
                -- Disable specific errors (E0401: Unable to import)
                args = { '--disable=E0401' }
              },
              pyflakes = { enabled = false },
              pycodestyle = { enabled = false },
              -- import sorting
              pyls_isort = { enabled = true },
            },
          },
        },
      }

      -- Setup LSP for Nvim Lua
      lspconfig.lua_ls.setup {
        on_attach = on_attach,
        on_init = function(client)
          if client.workspace_folders then
            local path = client.workspace_folders[1].name
            if vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc') then
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
