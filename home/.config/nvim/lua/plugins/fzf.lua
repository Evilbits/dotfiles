return {
  {
    'junegunn/fzf',
    dir = "~/.fzf",
    build = "./install --all",
    config = function()
      vim.cmd([[
        " Use ripgrep for fzf
        let $FZF_DEFAULT_COMMAND="rg --files --hidden --glob '!.git' --glob '!node_modules'"
      ]])
    end
  },
  {'junegunn/fzf.vim'},
  -- NerdTree icons
  {'ryanoasis/vim-devicons'},
  -- Jump to words/chars
  {
    'easymotion/vim-easymotion',
    config = function()
      vim.cmd([[
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
      ]])
    end
  },
}
