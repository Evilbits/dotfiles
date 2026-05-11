return {
  "folke/zen-mode.nvim",
  keys = {
    { "<leader>z", ":ZenMode<CR>" },
  },
  config = function()
    require("zen-mode").setup({
      window = {
        width = .8 -- width will be 50% of the editor width
      },
      on_open = function()
        vim.keymap.set("ca", "q", function()
          local ok, view = pcall(require, "zen-mode.view")
          if ok and view.is_open() then
            return "ZenMode"
          end
          return "q"
        end, { expr = true })

        vim.keymap.set("ca", "w", function()
          local ok, view = pcall(require, "zen-mode.view")
          if ok and view.is_open() then
            return "echo 'Close ZenMode first (:ZenMode or <leader>z)'"
          end
          return "w"
        end, { expr = true })
      end,
      on_close = function()
        vim.keymap.del("ca", "q")
        vim.keymap.del("ca", "w")
      end,
    })
  end
}
