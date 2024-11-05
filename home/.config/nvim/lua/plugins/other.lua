return {
  -- Automatically close brackets
  {'raimondi/delimitmate'},             
  -- Smooth scrolling
  {'psliwka/vim-smoothie'},
  -- Adds a symbol at line indents
  {'yggdroot/indentline'},
  -- Smarter surrounding of words
  {'tpope/vim-surround'},
  -- JS code formatter
  {
    'prettier/vim-prettier',
    build = 'yarn install --frozen-lockfile --production'
  }, 
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function() vim.fn["mkdp#util#install"]() end,
  },
  -- Keybind helper
  {'folke/which-key.nvim'},
  -- Automatically color hex codes
  {'norcalli/nvim-colorizer.lua'},
  -- Stops crashing when indexing large files
  {'vim-scripts/LargeFile'},
}
