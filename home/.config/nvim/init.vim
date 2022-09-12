silent! if plug#begin('~/.vim/plugged')
" UI 
Plug 'nvim-lualine/lualine.nvim'        " Status bar
Plug 'kyazdani42/nvim-web-devicons'     " Sweet icons
Plug 'mhinz/vim-startify'               " Custome start screen

" LSP support & syntax handling
Plug 'neovim/nvim-lspconfig'            " LSP configuration
Plug 'williamboman/nvim-lsp-installer'  " Language server installation tool
Plug 'w0rp/ale'                         " Async syntax highlighting and linting
Plug 'ray-x/lsp_signature.nvim'         " Function signatures
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'} " Better syntax highlighting
Plug 'kyazdani42/nvim-web-devicons'     " Development icons
Plug 'folke/trouble.nvim'               " LSP results in separate buffer

" nvim-cmp autocompletion
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-cmdline'
Plug 'hrsh7th/nvim-cmp'
" Plug 'hrsh7th/cmp-nvim-lsp-signature-help'

" Snippets
Plug 'hrsh7th/cmp-vsnip'
Plug 'hrsh7th/vim-vsnip'

" Git
Plug 'airblade/vim-gitgutter'           " Git status bar
Plug 'rhysd/git-messenger.vim'
Plug 'tpope/vim-fugitive'
Plug 'jreybert/vimagit'

" Navigation
Plug 'junegunn/fzf' , { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'scrooloose/nerdtree'              " Folder navigation
Plug 'ryanoasis/vim-devicons'           " Nerdtree icons
Plug 'easymotion/vim-easymotion'        " Jump to words or chars
"" Fuzzy finding for lists
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }

" Other
Plug 'raimondi/delimitmate'             " Automatically close brackets
Plug 'psliwka/vim-smoothie'             " Smooth scrolling
Plug 'yggdroot/indentline'              " Adds a symbol at line indents
Plug 'tpope/vim-surround'               " Smarter surrounding of words
Plug 'prettier/vim-prettier', { 'do': 'yarn install --frozen-lockfile --production' } " JS code formatter
Plug 'eslint/eslint'
Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() }, 'for': ['markdown', 'vim-plug']}
Plug 'folke/zen-mode.nvim'
Plug 'folke/which-key.nvim'             " Vim keybind helper
Plug 'norcalli/nvim-colorizer.lua'      " Color hex codes 
Plug 'vim-scripts/LargeFile'            " Stop crashing when indexing large files
call plug#end()
endif

" ====== Load lua config ======
lua << EOF
require('config')
EOF

" Automatically recompile Packer when saving config file
augroup packer_user_config
  autocmd!
  autocmd BufWritePost config.lua source <afile> | PackerCompile
augroup end

" reload vimrc when saved
map <leader>v :sp ~/.config/nvim/init.vim<cr>
au BufWritePost ~/.config/nvim/init.vim so ~/.config/nvim/init.vim

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

" Tabs
set tabstop=2                             " The width of a TAB is set to 2.
set shiftwidth=2                          " Indents will have a width of 2.
set expandtab                             " Expand TABs to spaces.
set number                                " Enable gutter line numbers
set softtabstop=0
set autoindent

lua require'colorizer'.setup()

" ====== Theme ======
if (has("termguicolors"))
  let &t_8f="\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b="\<Esc>[48;2;%lu;%lu;%lum"
endif

" ====== Key remapping ======
nnoremap <SPACE> <Nop>
nmap <space> <leader>

" remap cursor keys to practice using hjkl
noremap <Up> <Nop>
noremap <Down> <Nop>
noremap <Left> <Nop>
noremap <Right> <Nop>

" ====== Nerdtree config ======
" Keybind for opening Nerdtree
"map <silent> <C-n> :NERDTreeToggle<CR>
"let NERDTreeShowHidden=1                  " Start closed
"autocmd VimEnter * wincmd p               " Go to previous (last accessed) window.
"" Close Nerdtree if last in buffer
"autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
"" If another buffer tries to replace NERDTree, put it in the other window, and bring back NERDTree.
"autocmd BufEnter * if bufname('#') =~ 'NERD_tree_\d\+' && bufname('%') !~ 'NERD_tree_\d\+' && winnr('$') > 1 |
"    \ let buf=bufnr() | buffer# | execute "normal! \<C-W>w" | execute 'buffer'.buf | endif

" ====== Nerdtree config ======
let g:startify_change_to_dir = 0          " Don't cd to dir when opening file

" ====== Ale config ======
let g:ale_fixers = ['prettier', 'eslint'] " Fix files with prettier, and then ESLint.
let g:ale_fix_on_save = 1                 " Set this variable to 1 to fix files when you save them.
let g:ale_disable_lsp = 1                 " Disable lsp as we use nvim native lsp
let g:ale_set_highlights = 0              " Remove highlighting
" Set which linters to use
let g:ale_linters = {'javascript': ['prettier', 'eslint'] }
" Map different languages to above linters
let g:ale_linter_aliases = {'typescript': 'javascript', 'typescriptreact': 'javascript'}
" Automatic Typescript import from external modules
let g:ale_completion_tsserver_autoimport = 1

" ====== GitMessenger config ======
let g:git_messenger_always_into_popup = v:true
let g:git_messenger_include_diff = "current"

" ====== easymotion config ======
" Jump to word with `s{char}{char}{label}`
nmap s <Plug>(easymotion-overwin-f)
nmap <leader>s <Plug>(easymotion-overwin-f2)
let g:EasyMotion_smartcase = 1 " Case insensitive search
let g:EasyMotion_do_mapping = 0 " Disable default mappings
" Better colors when searching
hi link EasyMotionTarget ErrorMsg
hi link EasyMotionShade  Comment
hi link EasyMotionTarget2First MatchParen
hi link EasyMotionTarget2Second MatchParen

" ====== fzf config ======
" Use ripgrep for fzf
let $FZF_DEFAULT_COMMAND="rg --files --hidden --glob '!.git' --glob '!node_modules'"
