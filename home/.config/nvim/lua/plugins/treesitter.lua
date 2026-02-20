return {
  'nvim-treesitter/nvim-treesitter',
  event = 'CursorHold',
  build = ':TSUpdate',
  config = function()
    require 'nvim-treesitter.configs'.setup {
      ensure_installed = {
        "lua",
        "typescript",
        "javascript",
        "tsx",
        "terraform",
        "hcl",
        "markdown",
        "markdown_inline",
        "json",
        "yaml",
        "bash",
        "gitcommit",
        "gitignore",
        "css",
        "html",
      },
      highlight = {
        enable = true,
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "gnn",
          node_incremental = "grn",
          scope_incremental = "grc",
          node_decremental = "grm",
        },
      },
      indent = {
        enable = true,
      },
      -- nvim-ts-autotag
      autotag = {
        enable = true,
      },
    }
  end
}
