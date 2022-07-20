local nvim_lsp = require('lspconfig')

local on_attach = function(client, bufnr)
  -- Add any attach functionality here
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local opts = { noremap=true, silent=true }
end

require'lspconfig'.tsserver.setup{}

-- Plugins with configuration
require('plugins.lsp_signature')
require('plugins.lualine')
require('plugins.telescope')
require('plugins.treesitter')
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
capabilities = require('cmp_nvim_lsp').update_capabilities(capabilities)

local servers = { 'tsserver', 'gopls', 'graphql' }
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
-- Git keybinds
vim.api.nvim_set_keymap('n', '<leader>gs', '<cmd>lua require("telescope.builtin").git_status()<CR>', {})
-- Treesitter keybinds
vim.api.nvim_set_keymap('n', '<leader>t', '<cmd>lua require("telescope.builtin").treesitter()<CR>', {})
-- Other keybinds
vim.api.nvim_set_keymap('n', '<leader>gb', ':GitMessenger<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>gB', ':Git blame<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>r', ':NERDTreeFind<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>z', ':ZenMode<CR>', {})
