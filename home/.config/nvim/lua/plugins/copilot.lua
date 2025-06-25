local prompts = {
  -- Code related prompts
  --Explain = "Please explain how the following code works.",
  Review = "Please review the following code and provide suggestions for improvement.",
  Tests = "Please explain how the selected code works, then generate unit tests for it.",
  Refactor = "Please refactor the following code to improve its clarity and readability.",
  --FixCode = "Please fix the following code to make it work as intended.",
  --FixError = "Please explain the error in the following text and provide a solution.",
  BetterNamings = "Please provide better names for the following variables and functions.",
  Documentation = "Please provide documentation for the following code.",
  -- Text related prompts
  Summarize = "Please summarize the following text.",
  Spelling = "Please correct any grammar and spelling errors in the following text.",
  Wording = "Please improve the grammar and wording of the following text.",
  Concise = "Please rewrite the following text to make it more concise.",
}
return {
  { 'github/copilot.vim', enabled = true },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = {
      { "github/copilot.vim" },    -- or zbirenbaum/copilot.lua
      { "nvim-lua/plenary.nvim" }, -- for curl, log wrapper
    },
    build = "make tiktoken",       -- Only on MacOS or Linux
    branch = "main",
    opts = {
      -- debug = true, -- Enable debugging
      model = "claude-3.7-sonnet-thought",
      -- See Configuration section for rest
      prompts = {},
      mappings = {
        complete = {
          insert = '<C-s>',
        }
      }
    },
    config = function(_, opts)
      local chat = require("CopilotChat")
      local select = require("CopilotChat.select")
      opts.prompts.Explain = {
        prompt = [[/COPILOT_EXPLAIN
          Your task is to take the code snippet and explain it with gradually increasing complexity.
          Break down the code's functionality, purpose, and key components.
          The goal is to help the reader understand what the code does and how it works.

          Use the markdown format with codeblocks and inline code.
        ]],
      }
      opts.prompts.Fix = {
        prompt = [[/COPILOT_FIX
          Fix bugs in the below code from carefully and logically:
          Your task is to analyze the provided code snippet, identify
          any bugs or errors present, and provide a corrected version of the code
          that resolves these issues. Explain the problems you found in the
          original code and how your fixes address them. The corrected code should
          be functional, efficient, and adhere to the best practices of
          the given programming language.
        ]],
      }
      opts.prompts.Complete = {
        prompt = [[/COPILOT_GENERATE
          I have the following code.

          Please finish the code above carefully and logically.
          Respond just with the snippet of code that should be inserted.
        ]],
      }
      opts.prompts.Optimize = {
        prompt = [[/COPILOT_OPTIMIZE
          Your task is to analyze the provided code snippet and
          suggest improvements to optimize its performance. Identify areas
          where the code can be made more efficient, faster, or less
          resource-intensive. Provide specific suggestions for optimization,
          along with explanations of how these changes can enhance the code's
          performance. The optimized code should maintain the same functionality
          as the original code while demonstrating improved efficiency.
        ]]
      }
      opts.prompts.Commit = {
        prompt = [[/COPILOT_COMMIT
          I want you to act as a commit message generator. I will provide you
          with information about the task and the prefix for the task code, and
          I would like you to generate an appropriate commit message using the
          conventional commit format. Do not write any explanations or other
          words, just reply with the commit message.
          Start with a short headline as summary but then list the individual
          changes in more detail.
        ]],
        selection = function(source)
          return select.gitdiff(source, true)
        end,
      }

      -- Merge default prompts with custom prompts
      local function mergeTables(t1, t2)
        for k, v in pairs(t2) do
          t1[k] = v
        end
        return t1
      end
      opts.prompts = mergeTables(opts.prompts, prompts)
      chat.setup(opts)
    end,
    --keys = {
    --  {
    --    "<leader>cch",
    --    function()
    --      local actions = require("CopilotChat.actions")
    --      require("CopilotChat.integrations.fzflua").pick(actions.help_actions())
    --    end,
    --    desc = "CopilotChat - Help actions",
    --  },
    --  -- Show prompts actions with fzf-lua
    --  {
    --    "<leader>ccp",
    --    function()
    --      local actions = require("CopilotChat.actions")
    --      require("CopilotChat.integrations.fzflua").pick(actions.prompt_actions())
    --    end,
    --    desc = "CopilotChat - Prompt actions",
    --  },
    --},
  },
}
