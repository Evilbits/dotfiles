"execute pathogen#infect()
"if empty(glob('~/.vim/autoload/plug.vim'))
"  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
"    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
"  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
"endif

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

" Code snippets
Plug 'SirVer/ultisnips'

" C#
Plug 'OmniSharp/omnisharp-vim'

" Go
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }

" Automatically add end to code
Plug 'tpope/vim-endwise'

" Static code analysis for Ruby
Plug 'ngmy/vim-rubocop'

" Automatically close brackets
Plug 'raimondi/delimitmate'

" Git status bar
Plug 'airblade/vim-gitgutter'

" Git
"Plug 'tpope/vim-fugitive'

" ruby
Plug 'tpope/vim-rails'

" vue
Plug 'posva/vim-vue'

" javascript
Plug 'pangloss/vim-javascript'

" tsx
Plug 'leafgarland/typescript-vim'
Plug 'peitalin/vim-jsx-typescript'

" theme
Plug 'arcticicestudio/nord-vim'
"Plug 'dracula/vim',{'as':'dracula'}
"Plug 'ntk148v/vim-horizon'
Plug 'hzchirs/vim-material'
Plug 'folke/tokyonight.nvim'
call plug#end()
endif

" nerdtree
let NERDTreeShowHidden=1
" Use Nerdtree for browsing directories
" Auto start on opening Vim
map <silent> <C-n> :NERDTreeToggle<CR>
"autocmd vimenter * NERDTree
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

" Change default command for fzf.vim to show dotfiles
set wildmode=list:longest,list:full
set wildignore+=*.o,*.obj,.git,*.rbc,*.pyc,__pycache__,node_modules/*
" Set default Files to include hidden
"let $FZF_DEFAULT_COMMAND="find . -path '*/\.*' -type d -prune -o -type f -print -o -type l -print 2> /dev/null | sed s/^..//"
let $FZF_DEFAULT_COMMAND='rg --files'

" fzf shortcut
map ; :Files<CR>

" fzf extra commands
function! s:find_git_root()
  return system('git rev-parse --show-toplevel 2> /dev/null')[:-2]
endfunction
" search within git project
command! PFiles execute 'Files' s:find_git_root()
" search from home folder
command! HFiles execute 'Files ~/'

" remap cursor keys to practice using hjkl
noremap <Up> <Nop>
noremap <Down> <Nop>
noremap <Left> <Nop>
noremap <Right> <Nop>

" Fix files with prettier, and then ESLint.
let b:ale_fixers = ['prettier', 'eslint']
" Set this variable to 1 to fix files when you save them.
let g:ale_fix_on_save = 1
" Only use ESLint
let b:ale_linters = {'javascript': ['prettier', 'eslint'], 'vue': ['eslint', 'vls'], 'cs': ['OmniSharp'], 'go': ['gopls']}
" Run both javascript and vue linters for vue files.
let g:ale_linter_aliases = {'vue': ['vue', 'javascript'], 'typescript': 'javascript', 'typescriptreact': 'javascript'}
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
set backupdir=~/.vim/tmp/backup
set directory=~/.vim/tmp/swap
" persit undo history
set undofile " Maintain undo history between sessions
set undodir=~/.vim/tmp/undo

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

" Vue highligting
" Sometimes the highlighting can't 'catch up' with Vim which leads to no
" syntax highlighting.
" See: https://github.com/posva/vim-vue/issues/72
autocmd FileType vue syntax sync fromstart
autocmd BufRead,BufNewFile *.vue setlocal filetype=vue.html.javascript.css.less.pug
" Apparently helps with some of the speed concerns by disabling some
" preprocessing
let g:vue_disable_pre_processors=1

" Stops delay on 'O' if pressed after ESC
set ttimeoutlen=100
syntax on
set autoread " Auto load file if changed
filetype on " Enable file type detection
filetype plugin indent on " Enable loading the plugin files for specific file types
set encoding=utf-8
set ffs=unix,dos,mac
let g:airline_theme='luna'

nmap <space> <leader>

""" Load lua config
lua << EOF
require('config')
EOF
augroup omnisharp_commands
	autocmd!
	autocmd CursorHold *.cs OmniSharpTypeLookup
augroup END

"let g:OmniSharp_server_path = '/home/rasmus/.omnisharp/run'
let g:OmniSharp_server_use_mono = 1
let g:OmniSharp_selector_ui = 'fzf'
let g:OmniSharp_selector_findusages = 'fzf'

" Ultisnip
let g:UltiSnipsExpandTrigger="<tab>"
let g:UltiSnipsJumpForwardTrigger="<c-b>"
let g:UltiSnipsJumpBackwardTrigger="<c-z>"

" Below there be theming
"let g:material_style='oceanic'
set termguicolors
if (has("termguicolors"))
  let &t_8f="\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b="\<Esc>[48;2;%lu;%lu;%lum"
endif
"
"set t_Co=256
"if &term =~ '256color'
"  set t_ut=
"endif
"set background=dark
"colorscheme tokyonight
colorscheme vim-material
"colorscheme nord
