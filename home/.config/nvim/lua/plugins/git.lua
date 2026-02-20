-- General Git setup
return {
  {
    "lewis6991/gitsigns.nvim",
    opts = {},
    keys = {
      { "<leader>d", "<cmd>Gitsigns diffthis<CR>" },
    },
  },
  {
    "rhysd/git-messenger.vim",
    keys = {
      { "<leader>gb", ":GitMessenger<CR>" },
    },
  },
  {
    "tpope/vim-fugitive",
    keys = {
      { "<leader>gB", ":Git blame<CR>" },
    },
  },
}