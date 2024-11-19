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
  -- Jump to words/chars
  {
    'ggandor/leap.nvim',
    config = function()
      vim.keymap.set({'n', 'x', 'o'}, 's',  '<Plug>(leap)')
      vim.keymap.set({'n', 'x', 'o'}, 'S',  '<Plug>(leap-from-window)')
    end,
  }
}
