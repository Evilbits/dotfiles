return {
  { 'github/copilot.vim', enabled = true },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    enabled = true,
    dependencies = {
      { "github/copilot.vim" },    -- or zbirenbaum/copilot.lua
      { "nvim-lua/plenary.nvim" }, -- for curl, log wrapper
    },
    build = "make tiktoken",       -- Only on MacOS or Linux
    branch = "main",
    opts = {
      -- debug = true, -- Enable debugging
      -- model = "gpt-5",
      model = 'claude-sonnet-4.5',
      -- See Configuration section for rest
      prompts = {},
      mappings = {
        complete = {
          insert = '<C-s>',
        }
      }
    },
  },
}
