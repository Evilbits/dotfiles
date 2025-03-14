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
      { 'sharkdp/fd' }
    },
    config = function()
      local builtin = require('telescope.builtin')
      vim.keymap.set('n', '<C-f>', builtin.git_files, {})
      vim.keymap.set('n', '<Leader>pf', builtin.find_files, {})
      vim.keymap.set('n', '<Leader>ps', builtin.live_grep, {})
      vim.keymap.set('n', '<Leader>pS', builtin.current_buffer_fuzzy_find, {})
      vim.keymap.set('n', '<Leader>b', vim.cmd.Buffers, {})

      require('telescope').setup {
        defaults = {
          file_ignore_patterns = {
            '%.pdf'
            -- ".git/", 'node_modules/', '__pycache__', 'static', '%.jpg', '%.pdf', 'yarn.lock'
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
          layout_config = {
            horizontal = {
              prompt_position = "bottom",
              preview_width = 0.55,
              results_width = 0.8,
            },
            vertical = {
              mirror = false,
            },
            width = 0.87,
            height = 0.80,
            preview_cutoff = 120,
          },
          file_sorter = require("telescope.sorters").get_fuzzy_file,
          generic_sorter = require("telescope.sorters").get_generic_fuzzy_sorter,
          path_display = { "truncate" },
          winblend = 0,
          border = {},
          borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
          color_devicons = true,
          use_less = true,
          set_env = { ["COLORTERM"] = "truecolor" }, -- default = nil,
          file_previewer = require("telescope.previewers").vim_buffer_cat.new,
          grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
          qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
          -- Developer configurations: Not meant for general override
          buffer_previewer_maker = require("telescope.previewers").buffer_previewer_maker,
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
    end
  }
}
