return {
  "folke/zen-mode.nvim",
  config = function()
    require("zen-mode").setup({
      window = {
        width = .8 -- width will be 50% of the editor width
      }
    })
  end
}
