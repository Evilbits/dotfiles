local nvim_lsp = require('lspconfig')

local on_attach = function(client, bufnr)
  -- Add any attach functionality here
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local opts = { noremap=true, silent=true }
end

-- Add additional capabilities supported by nvim-cmp
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').update_capabilities(capabilities)

-- nvim-cmp setup
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
    ['<C-p>'] = cmp.mapping.select_prev_item(),
    ['<C-n>'] = cmp.mapping.select_next_item(),
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

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
local servers = { 'tsserver', 'gopls' }
for _, lsp in ipairs(servers) do
  nvim_lsp[lsp].setup {
    on_attach = on_attach,
    capabilities = capabilities,
    flags = {
      debounce_text_changes = 150,
    }
  }
end

require'lspconfig'.tsserver.setup{}

-- Setup function signatures
require'lsp_signature'.setup({
  bind = true, -- This is mandatory, otherwise border config won't get registered.
  handler_opts = {
    border = "rounded"   -- double, rounded, single, shadow, none
  },
})

-- Lualine
--require('evil_lualine')
require('lualine').setup({ 
  options = { transparent = true },
  sections = {
    lualine_b = {'diff', 'diagnostics'},
  }
})

-- Treesitter
require'nvim-treesitter.configs'.setup {
  ensure_installed = "maintained", -- one of "all", "maintained" (parsers with maintainers), or a list of languages
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
  }
}

-- Telescope fzf
require('telescope').setup {
  defaults = {
    file_ignore_patterns = {
      '.git/', 'node_modules/', '__pycache__/'
    },
  }
}
require('telescope').load_extension('fzf')

-- Trouble setup
require('trouble').setup {}

local theme = require('telescope.themes').get_dropdown({})
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
vim.api.nvim_set_keymap('n', '<leader>r', ':NERDTreeFind<CR>', {})
