local nvim_lsp = require('lspconfig')

local on_attach = function(client, bufnr)
  -- Add any attach functionality here
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local opts = { noremap=true, silent=true }
end

require'lspconfig'.tsserver.setup{}
--require'lspconfig'.ruby_lsp.setup{}
require'lspconfig'.solargraph.setup{}

-- Plugins with configuration
require('plugins.lsp_signature')
require('plugins.lualine')
require('plugins.telescope')
require('plugins.nvim_cmp')
require('plugins.zenmode')

-- Simple plugin setup
require('trouble').setup {} -- Code diagnostics

require("which-key").setup {} -- Keybind helper

---- LSP final setup ----
-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
-- Add additional capabilities supported by nvim-cmp
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

local servers = { 'tsserver', 'gopls', 'graphql', 'solargraph', 'pyright' }
for _, lsp in ipairs(servers) do
  nvim_lsp[lsp].setup {
    on_attach = on_attach,
    capabilities = capabilities,
    flags = {
      debounce_text_changes = 150,
    }
  }
end

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
vim.api.nvim_set_keymap('n', '<leader>g', ':Magit<CR>', {})
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

 -- use {
 --   'ms-jpq/chadtree',
 --   run = ':CHADdeps',
 --   requires = { 'arcticicestudio/nord-dircolors' },
 --   config = function()
 --     vim.api.nvim_set_var("chadtree_settings", {
 --       ["keymap.change_dir"] = {  },
 --       ["keymap.change_focus"] = {  },
 --       ["keymap.change_focus_up"] = {  },
 --       ["keymap.refresh"] = { "<c-r>", "R" },
 --       ["keymap.primary"] = { "<enter>", "o" },
 --       ["keymap.h_split"] = { "go" },
 --       ["keymap.v_split"] = { "w" },
 --       ["keymap.open_sys"] = { "O" },
 --       ["view.width"] = 60,
 --       ["view.window_options"] = {
 --         ["number"] = true,
 --         ["relativenumber"] = true,
 --       },
 --     })
 --   end
 -- }

  -- use {
  --   'numToStr/Comment.nvim',
  --   config = function()
  --       require('Comment').setup()
  --   end
  -- }

  use {
    'ThePrimeagen/harpoon',
    config = function()
        require('harpoon').setup()
    end
  }

  --use({
  --  {
  --    'nvim-treesitter/nvim-treesitter',
  --    event = 'CursorHold',
  --    run = ':TSUpdate',
  --    --run = function()
  --    --    local ts_update = require('nvim-treesitter.install').update({ with_sync = true })
  --    --    ts_update()
  --    --end,
  --    config = function()
  --      require('plugins.treesitter')
  --    end,
  --  },
  --  { 'windwp/nvim-ts-autotag', after = 'nvim-treesitter' },
  --  { 'JoosepAlviste/nvim-ts-context-commentstring', after = 'nvim-treesitter' },
  --})

  -- use({ 
  --   'nvim-treesitter/nvim-treesitter-context', 
  --   config = function()
  --     require('plugins.treesitter_context')
  --   end
  -- })


  -- external config files
  reload('plugins.theme').init(use)
end)
