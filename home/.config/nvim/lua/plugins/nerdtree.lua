return {
  'scrooloose/nerdtree',
  config = function()
    vim.cmd([[
      " ====== Nerdtree config ======
      let NERDTreeShowHidden=1                  " Start closed
      autocmd VimEnter * wincmd p               " Go to previous (last accessed) window.
      "" Close Nerdtree if last in buffer
      autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
      "" If another buffer tries to replace NERDTree, put it in the other window, and bring back NERDTree.
      autocmd BufEnter * if bufname('#') =~ 'NERD_tree_\d\+' && bufname('%') !~ 'NERD_tree_\d\+' && winnr('$') > 1 |
          \ let buf=bufnr() | buffer# | execute "normal! \<C-W>w" | execute 'buffer'.buf | endif
      " Fix for: https://github.com/preservim/nerdtree/issues/1321?ts=4
      let g:NERDTreeMinimalMenu=1
      let g:NERDTreeWinSize=50 " Increase width
      
      " ====== Nerdtree config ======
      let g:startify_change_to_dir = 0          " Don't cd to dir when opening file
    ]])
  end
}

