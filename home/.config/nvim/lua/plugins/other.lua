return {
  -- Automatically close brackets
  { 'raimondi/delimitmate' },
  -- Smooth scrolling
  { 'psliwka/vim-smoothie' },
  -- Adds a symbol at line indents
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    opts = {},
  },
  -- Smarter surrounding of words
  { 'tpope/vim-surround' },
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
  { 'folke/which-key.nvim' },
  {
    'echasnovski/mini.ai',
    version = '*',
    config = function()
      require('mini.ai').setup()
    end,
  },
  -- Automatically color hex codes
  { 'norcalli/nvim-colorizer.lua' },
  -- Stops crashing when indexing large files
  { 'vim-scripts/LargeFile' },
  {
    'mbbill/undotree',
    config = function()
      vim.keymap.set('n', '<Leader>u', vim.cmd.UndotreeToggle, {})
    end
  }
}
