execute pathogen#infect()
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
Plug 'junegunn/fzf' , { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'scrooloose/nerdtree'
Plug 'yggdroot/indentline'
Plug 'bling/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" Git status bar
Plug 'airblade/vim-gitgutter'

" ruby
Plug 'tpope/vim-rails'

" javascript
Plug 'pangloss/vim-javascript'

" theme
"Plug 'dracula/vim',{'as':'dracula'}
"Plug 'ntk148v/vim-horizon'
Plug 'hzchirs/vim-material'

call plug#end()

" Set theme of bottom bar
let g:airline_theme='luna'
let g:airline_powerline_fonts = 1

" nerdtree
let NERDTreeShowHidden=0
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

" dracula
let g:dracula_italic = 0
let g:dracula_colorterm = 0

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
set softtabstop=2   " Sets the number of columns for a TAB.
set expandtab       " Expand TABs to spaces.
set autoindent
set number

syntax on
set autoread " Auto load file if changed
filetype on " Enable file type detection
filetype plugin indent on " Enable loading the plugin files for specific file types
set encoding=utf-8
set ffs=unix,dos,mac
set t_Co=256
let g:airline_theme='material'
set background=dark
if (has("termguicolors"))
  set termguicolors
endif
colorscheme vim-material
