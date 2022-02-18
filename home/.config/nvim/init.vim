silent! if plug#begin('~/.vim/plugged')
" UI 
Plug 'nvim-lualine/lualine.nvim'        " Status bar
Plug 'kyazdani42/nvim-web-devicons'     " Sweet icons
Plug 'mhinz/vim-startify'               " Custome start screen

" Themes
Plug 'sainnhe/sonokai'
"Plug 'arcticicestudio/nord-vim'
"Plug 'folke/tokyonight.nvim'

" LSP support & syntax handling
Plug 'neovim/nvim-lspconfig'            " LSP configuration
Plug 'williamboman/nvim-lsp-installer'  " Language server installation tool
Plug 'w0rp/ale'                         " Async syntax highlighting and linting
Plug 'ray-x/lsp_signature.nvim'         " Function signatures

" nvim-cmp autocompletion
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-cmdline'
Plug 'hrsh7th/nvim-cmp'

" Snippets
Plug 'hrsh7th/cmp-vsnip'
Plug 'hrsh7th/vim-vsnip'

" Git
Plug 'airblade/vim-gitgutter'           " Git status bar

" Navigation
Plug 'junegunn/fzf' , { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'                 " Fuzzy finder
Plug 'scrooloose/nerdtree'              " Folder navigation

" Other
Plug 'raimondi/delimitmate'             " Automatically close brackets
Plug 'psliwka/vim-smoothie'             " Smooth scrolling
Plug 'yggdroot/indentline'
Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() }, 'for': ['markdown', 'vim-plug']}
call plug#end()
endif

" ====== Load lua config ======
lua << EOF
require('config')
EOF

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
filetype on                               " Enable file type detection
filetype plugin indent on                 " Enable loading the plugin files for specific file types

" Tabs
set tabstop=2                             " The width of a TAB is set to 2.
set shiftwidth=2                          " Indents will have a width of 2.
set expandtab                             " Expand TABs to spaces.
set number                                " Enable gutter line numbers
set softtabstop=0
set autoindent

" ====== Theme ======
if (has("termguicolors"))
  let &t_8f="\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b="\<Esc>[48;2;%lu;%lu;%lum"
endif

let g:sonokai_style = 'andromeda'
colorscheme sonokai

" ====== Key remapping ======
nnoremap <SPACE> <Nop>
nmap <space> <leader>
" fzf shortcut
map ; :Files<CR>

" remap cursor keys to practice using hjkl
noremap <Up> <Nop>
noremap <Down> <Nop>
noremap <Left> <Nop>
noremap <Right> <Nop>

" ====== Nerdtree config ======
" Keybind for opening Nerdtree
map <silent> <C-n> :NERDTreeToggle<CR>
let NERDTreeShowHidden=1                  " Start closed
autocmd VimEnter * wincmd p               " Go to previous (last accessed) window.
" Close Nerdtree if last in buffer
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

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

" ====== fzf config ======
" Use ripgrep for fzf
let g:fzf_layout = {'up':'~90%', 'window': { 'width': 0.8, 'height': 0.8,'yoffset':0.5,'xoffset': 0.5, 'border': 'sharp' } }
let g:fzf_tags_command = 'ctags -R'
let $FZF_DEFAULT_COMMAND="rg --files --hidden --glob '!.git' --glob '!node_modules'"
set wildignore+=*.o,*.obj,.git,*.rbc,*.pyc,__pycache__,node_modules/*

" change grep to use RipGrep
if executable('rg')
  set grepprg=rg\ --no-heading\ --vimgrep\ --smart-case
  set grepformat=%f:%l:%c:%m
endif

