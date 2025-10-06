return {
  {
    'nvim-telescope/telescope.nvim',
    dependencies = {
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        config = function()
          require("telescope").load_extension("fzf")
        end,
      },
      { 'sharkdp/fd' },
      { 'nvim-telescope/telescope-ui-select.nvim' }
    },
    config = function()
      local builtin = require('telescope.builtin')
      vim.keymap.set('n', '<C-f>', builtin.find_files, {})
      vim.keymap.set('n', '<Leader>pf', builtin.git_files, {})
      vim.keymap.set('n', '<Leader>ps', builtin.live_grep, {})
      vim.keymap.set('n', '<Leader>pS', builtin.current_buffer_fuzzy_find, {})
      -- vim.keymap.set('n', '<Leader>b', vim.cmd.Buffers, {})
      vim.keymap.set('n', '<Leader>b', builtin.buffers, {})
      vim.keymap.set('n', '<Leader>pd', builtin.diagnostics, {})

      require('telescope').setup {
        defaults = {
          file_ignore_patterns = {
            ".git/", 'node_modules/', '__pycache__', 'static', '%.jpg', '%.pdf'
          },
          vimgrep_arguments = {
            "rg",
            "--color=never",
            "--no-heading",
            "--hidden",
            "--with-filename",
            "--line-number",
            "--column",
            "--ignore-case",
          },
          prompt_prefix = "   ",
          selection_caret = "  ",
          entry_prefix = "  ",
          initial_mode = "insert",
          selection_strategy = "reset",
          sorting_strategy = "descending",
          layout_strategy = "horizontal",
        },
        pickers = {
          find_files = {
            find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
          },
          git_files = {
            use_git_root = true,
            show_untracked = true,
          },
        },
        extensions = {
          fzf = {
            fuzzy = true,                   -- false will only do exact matching
            override_generic_sorter = true, -- override the generic sorter
            override_file_sorter = true,    -- override the file sorter
            case_mode = "ignore_case",      -- or "ignore_case" or "respect_case"
            -- the default case_mode is "smart_case"
          }
        }
      }
      require('telescope').load_extension('fzf')
      require("telescope").load_extension("ui-select")
    end
  }
}
