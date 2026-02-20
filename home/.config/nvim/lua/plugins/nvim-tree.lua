return {
  "nvim-tree/nvim-tree.lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    { "<C-n>",     "<cmd>NvimTreeToggle<CR>" },
    { "<leader>r", "<cmd>NvimTreeFindFile<CR>" },
  },
  opts = {
    view     = { width = 50 },
    filters  = { dotfiles = false },
    renderer = { group_empty = true },
    git      = { enable = false },
  },
}