-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out,                            "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.api.nvim_set_keymap('', '<Space>', '<Nop>', { noremap = true, silent = true })

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "habamax" } },
  -- automatically check for plugin updates
  checker = { enabled = true },
})


-- vim.api.nvim_set_keymap('n', '<C-d>', '<C-d>zz', { noremap = true })
-- vim.api.nvim_set_keymap('n', '<C-u>', '<C-u>zz', { noremap = true })

-- Git keybinds
vim.api.nvim_set_keymap('n', '<leader>gs', '<cmd>lua require("telescope.builtin").git_status()<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>d', ':GitGutterDiffOrig<CR>', {})
-- Treesitter keybinds
vim.api.nvim_set_keymap('n', '<leader>t', '<cmd>lua require("telescope.builtin").treesitter()<CR>', {})
-- CopilotChat keybinds
vim.keymap.set({ 'n' }, '<C-s>g', ':CopilotChatCommit<CR>', {})
vim.keymap.set({ 'n', 'v' }, '<C-s>c', ':CopilotChatToggle<CR>', {})
vim.keymap.set({ 'v' }, '<C-s>aa',
  ":lua require('CopilotChat.integrations.telescope').pick(require('CopilotChat.actions').prompt_actions({selection = require('CopilotChat.select').visual}))<CR>",
  {}) -- Opens up a Telescope buffer for the current selection and can execute commands on it
vim.keymap.set({ 'v' }, '<C-s>ac', ':CopilotChatComplete<CR>', {})
vim.keymap.set({ 'v' }, '<C-s>ao', ':CopilotChatOptimize<CR>', {})
vim.keymap.set({ 'v' }, '<C-s>af', ':CopilotChatFix<CR>', {})
vim.keymap.set({ 'v' }, '<C-s>at', ':CopilotChatTests<CR>', {})
vim.keymap.set({ 'v' }, '<C-s>e', ':CopilotChatExplain<CR>', {})
-- Other keybinds
vim.keymap.set("n", "<leader>rr", vim.lsp.buf.rename, {})
vim.api.nvim_set_keymap('n', '<leader>gb', ':GitMessenger<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>gB', ':Git blame<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>r', ':NERDTreeFind<CR>', {})
vim.api.nvim_set_keymap('n', '<C-n>', ':NERDTreeToggle<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>z', ':ZenMode<CR>', {})

-- TODO: Covert to Lua
vim.cmd([[
  " ====== General config ======
  set ttimeoutlen=100                       " Stops delay on 'O' if pressed after ESC
  set autoread                              " Auto load file if changed
  set encoding=utf-8                        " Default encoding
  set ffs=unix,dos,mac                      " Set fileformat
  set undofile                              " Maintain undo history between sessions
  set backupdir=~/.config/nvim/tmp/backup   " Set backup directory
  set directory=~/.config/nvim/tmp/swap     " Set swapfile directory
  set undodir=~/.config/nvim/tmp/undo       " Set undo directory
  set scrolljump=5                          " Change default amount of lines scrolled
  set termguicolors                         " Rich colors
  set cursorline                            " Highlight current line
  set mouse=                                " Disable mouse
  filetype on                               " Enable file type detection
  filetype plugin indent on                 " Enable loading the plugin files for specific file types
  set clipboard=unnamed " Copy to global clipboard

  " Tabs
  set tabstop=2                             " The width of a TAB is set to 2.
  set shiftwidth=2                          " Indents will have a width of 2.
  set expandtab                             " Expand TABs to spaces.
  "set relativenumber                        " Relative gutter line numbers
  set number relativenumber
  "set number                                " Enable gutter line numbers
  set softtabstop=0
  set autoindent

  " ====== Theme ======
  if (has("termguicolors"))
    let &t_8f="\<Esc>[38;2;%lu;%lu;%lum"
    let &t_8b="\<Esc>[48;2;%lu;%lu;%lum"
  endif

  " ====== Key remapping ======
  nnoremap <SPACE> <Nop>
  nmap <space> <leader>
]])

vim.g.catppuccin_flavour = "macchiato"
vim.cmd [[colorscheme catppuccin]]
