silent! if plug#begin('~/.vim/plugged')
Plug 'junegunn/fzf' , { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'scrooloose/nerdtree'
Plug 'yggdroot/indentline'
Plug 'bling/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'w0rp/ale'
Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() }, 'for': ['markdown', 'vim-plug']}

" Nvim
Plug 'neovim/nvim-lspconfig'
Plug 'williamboman/nvim-lsp-installer'

" nvim-cmp autocompletion
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-cmdline'
Plug 'hrsh7th/nvim-cmp'
Plug 'ray-x/lsp_signature.nvim' " Function signatures

" Code snippets
"Plug 'SirVer/ultisnips'

" Automatically close brackets
Plug 'raimondi/delimitmate'

" Git status bar
Plug 'airblade/vim-gitgutter'

" theme
Plug 'arcticicestudio/nord-vim'
Plug 'folke/tokyonight.nvim'
"Plug 'dracula/vim',{'as':'dracula'}
"Plug 'ntk148v/vim-horizon'
"Plug 'gkeep/iceberg-dark'
"Plug 'cocopon/iceberg.vim'
"Plug 'hzchirs/vim-material'
"Plug 'bluz71/vim-nightfly-guicolors'
"Plug 'connorholyday/vim-snazzy'
"Plug 'embark-theme/vim', { 'as': 'embark', 'branch': 'main' }
call plug#end()
endif

" nerdtree
let NERDTreeShowHidden=1
" Use Nerdtree for browsing directories
" Auto start on opening Vim
map <silent> <C-n> :NERDTreeToggle<CR>
" Go to previous (last accessed) window.
autocmd VimEnter * wincmd p
" Close Nerdtree if last in buffer
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

" air-line
let g:airline_powerline_fonts = 1

if !exists('g:airline_symbols')
  let g:airline_symbols = {}
endif

" unicode symbols
let g:airline_left_sep = '»'
let g:airline_left_sep = '▶'
let g:airline_right_sep = '«'
let g:airline_right_sep = '◀'
let g:airline_symbols.linenr = '␊'
let g:airline_symbols.linenr = '␤'
let g:airline_symbols.linenr = '¶'
let g:airline_symbols.branch = '⎇'
let g:airline_symbols.paste = 'ρ'
let g:airline_symbols.paste = 'Þ'
let g:airline_symbols.paste = '∥'
let g:airline_symbols.whitespace = 'Ξ'

" airline symbols
let g:airline_left_sep = ''
let g:airline_left_alt_sep = ''
let g:airline_right_sep = ''
let g:airline_right_alt_sep = ''
let g:airline_symbols.branch = ''
let g:airline_symbols.readonly = ''
let g:airline_symbols.linenr = ''

" Use rg for fzf
let $FZF_DEFAULT_COMMAND="rg --files --hidden --glob '!.git'"
set wildignore+=*.o,*.obj,.git,*.rbc,*.pyc,__pycache__,node_modules/*

" fzf shortcut
map ; :Files<CR>

" fzf extra commands
function! s:find_git_root()
  return system('git rev-parse --show-toplevel 2> /dev/null')[:-2]
endfunction

" remap cursor keys to practice using hjkl
noremap <Up> <Nop>
noremap <Down> <Nop>
noremap <Left> <Nop>
noremap <Right> <Nop>

" Fix files with prettier, and then ESLint.
let g:ale_fixers = ['prettier', 'eslint']
" Set this variable to 1 to fix files when you save them.
let g:ale_fix_on_save = 1
" Disable lsp as we use nvim native lsp
let g:ale_disable_lsp = 1
" Only use ESLint
let g:ale_linters = {'javascript': ['prettier', 'eslint'] }
let g:ale_linter_aliases = {'typescript': 'javascript', 'typescriptreact': 'javascript'}
" Remove highlighting
let g:ale_set_highlights = 0
" Automatic Typescript import from external modules
let g:ale_completion_tsserver_autoimport = 1

" change grep to use RipGrep
if executable('rg')
  set grepprg=rg\ --no-heading\ --vimgrep\ --smart-case
  set grepformat=%f:%l:%c:%m
endif

" History and backup
set backupdir=~/.config/nvim/tmp/backup
set directory=~/.config/nvim/tmp/swap
" persit undo history
set undofile " Maintain undo history between sessions
set undodir=~/.config/nvim/tmp/undo

" Tabs
set tabstop=2       " The width of a TAB is set to 2.
set shiftwidth=2    " Indents will have a width of 2.
set softtabstop=0
set noexpandtab
"set expandtab       " Expand TABs to spaces.
set autoindent
set number

" Remove whitespaces
let g:lessspace_enabled = 1
" Don't enable for markdown as double space is a <br>
let g:lessspace_blacklist = ['markdown']


" Stops delay on 'O' if pressed after ESC
set ttimeoutlen=100
syntax on
set autoread " Auto load file if changed
filetype on " Enable file type detection
filetype plugin indent on " Enable loading the plugin files for specific file types
set encoding=utf-8
set ffs=unix,dos,mac

""" Load lua config
lua << EOF
	require('config')
EOF

" Ultisnip
let g:UltiSnipsExpandTrigger="<tab>"
let g:UltiSnipsJumpForwardTrigger="<c-b>"
let g:UltiSnipsJumpBackwardTrigger="<c-z>"

" Below there be theming
"let g:airline_theme='deus'
set termguicolors
if (has("termguicolors"))
  let &t_8f="\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b="\<Esc>[48;2;%lu;%lu;%lum"
endif

"set background=dark
"colorscheme iceberg
let g:airline_theme='luna'
colorscheme tokyonight
