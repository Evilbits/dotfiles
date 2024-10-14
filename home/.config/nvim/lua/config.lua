local nvim_lsp = require('lspconfig')

local on_attach = function(client, bufnr)
  -- Add any attach functionality here
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local opts = { noremap=true, silent=true }
end

-- Plugins with configuration
require('plugins.lsp_signature')
require('plugins.lualine')
require('plugins.telescope')
require('plugins.nvim_cmp')
require('plugins.zenmode')

-- Simple plugin setup
require('trouble').setup {} -- Code diagnostics

require("which-key").setup {} -- Keybind helper
require("noice").setup({
  lsp = {
    signature = {
      enabled = false
    }
  },
  messages = {
    enabled = false
  }
})

---- LSP final setup ----
-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
-- Add additional capabilities supported by nvim-cmp
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

local servers = { 'pylsp', 'ts_ls' }
for _, lsp in ipairs(servers) do
  nvim_lsp[lsp].setup {
    on_attach = on_attach,
    capabilities = capabilities,
    flags = {
      debounce_text_changes = 150,
    }
  }
end

nvim_lsp.pylsp.setup {
  settings = {
      pylsp = {
        plugins = {
            -- formatter options
            black = { enabled = true },
            -- autopep8 = { enabled = false },
            -- yapf = { enabled = false },
            -- -- linter options
            -- pylint = { enabled = true, executable = "pylint" },
            -- pyflakes = { enabled = false },
            -- pycodestyle = { enabled = false },
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

-- Search keybinds
vim.api.nvim_set_keymap('n', '<Leader>ff', '<cmd>lua require("telescope.builtin").find_files({hidden = true})<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>fg', '<cmd>lua require("telescope.builtin").current_buffer_fuzzy_find()<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>fG', '<cmd>lua require("telescope.builtin").live_grep()<CR>', {})
-- LSP Keybinds
vim.api.nvim_set_keymap('n', '<leader>gd', '<cmd>lua require("telescope.builtin").lsp_references()<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>gD', '<cmd>lua require("telescope.builtin").lsp_definitions()<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>gc', ':Trouble document_diagnostics<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>gv', ':Trouble quickfix<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>gi', '<cmd>lua require("telescope.builtin").lsp_implementations()<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>gt', '<cmd>lua require("telescope.builtin").lsp_type_definitions()<CR>', {})
vim.api.nvim_set_keymap('n', '<C-s>', '<cmd>lua vim.lsp.buf.hover()<CR>', {})
-- CHADtree
--vim.api.nvim_set_keymap('n', '<C-n>', ':CHADopen<CR>', {})
-- Git keybinds
vim.api.nvim_set_keymap('n', '<leader>gs', '<cmd>lua require("telescope.builtin").git_status()<CR>', {})
-- Treesitter keybinds
vim.api.nvim_set_keymap('n', '<leader>t', '<cmd>lua require("telescope.builtin").treesitter()<CR>', {})
-- Other keybinds
vim.api.nvim_set_keymap('n', '<leader>gb', ':GitMessenger<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>gB', ':Git blame<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>r', ':NERDTreeFind<CR>', {})
vim.api.nvim_set_keymap('n', '<C-n>', ':NERDTreeToggle<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>z', ':ZenMode<CR>', {})

local function reload(name)
  require('plenary.reload').reload_module(name, true)
  return require(name)
end

return require('packer').startup(function()
  use 'wbthomason/packer.nvim'
  use "nvim-lua/plenary.nvim"

  use {
    'rcarriga/nvim-notify',
    config = function ()
      require("notify").setup {
        animate = false,
        stages = 'static',
      }
      vim.notify = require('notify')
    end
  }

  use {
    'ThePrimeagen/harpoon',
    branch = "harpoon2",
    requires = { {"nvim-lua/plenary.nvim"} },
    config = function()
        require('harpoon').setup()
    end
  }

  use {
    'nvim-treesitter/nvim-treesitter',
    event = 'CursorHold',
    run = ':TSUpdate',
    --run = function()
    --    local ts_update = require('nvim-treesitter.install').update({ with_sync = true })
    --    ts_update()
    --end,
    config = function()
      require('plugins.treesitter')
    end
  }

  use { 
    'nvim-treesitter/nvim-treesitter-context', 
    config = function()
      require('plugins.treesitter_context')
    end
  }


  -- external config files
  reload('plugins.theme').init(use)
end)
