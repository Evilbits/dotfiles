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
    on_attach = function(bufnr)
      local api = require("nvim-tree.api")
      api.config.mappings.default_on_attach(bufnr)
      vim.keymap.del("n", "s", { buffer = bufnr })
    end,
  },
}