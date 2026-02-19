return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    opts = {
      split_side = "right",
      split_width_percentage = 0.35,
      track_selection = true,
      terminal_cmd = vim.fn.expand("~/.local/bin/claude"),
    },
    keys = {
      { "<C-s>a", "<cmd>ClaudeCodeFocus<cr>",                    desc = "Focus Claude Code" },
      { "<C-s>a", "<C-\\><C-n><cmd>ClaudeCodeFocus<cr>", mode = "t", desc = "Return to editor" },
      { "<C-s>a", "<cmd>ClaudeCodeSend<cr>",  mode = "v",        desc = "Send selection to Claude" },
      { "<leader>aa", "<cmd>ClaudeCode<cr>",                     desc = "Toggle Claude Code" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffAccept<cr>",           desc = "Accept Claude diff" },
      { "<leader>aD", "<cmd>ClaudeCodeDiffDeny<cr>",             desc = "Deny Claude diff" },
    },
  },
}
