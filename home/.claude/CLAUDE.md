# Global Claude Instructions

## Safety
- Before running any command, briefly describe what it does.
- Before any destructive operation (deleting files, force pushes, dropping data, etc. — this list is not exhaustive), warn in bold and require explicit confirmation.
- Never push to a remote without explicit confirmation.

## Implementation Workflow
- When discussing architectural or implementation topics, present a plan split into distinct steps. Each step should encapsulate one logical area of change (e.g. a layer, service, or concern — multiple can be grouped if they fall under the same umbrella).
- Before implementing each step, show the exact code changes (diffs or full snippets) you intend to make and explain *why* each change is made that way. Only after presenting this detail should you ask for approval. Never ask "are you ready for step N?" without first showing the concrete changes and your reasoning.
- When showing diffs, include generous context — at minimum 10–15 lines before and after each change, more if the surrounding code is relevant to understanding the change. Never cut off a function in the middle.
- If a task or requirement is ambiguous with multiple valid interpretations, ask before assuming.

## Commit Messages
- Format: `<type>(<optional scope>): <TICKET-ID> - <short description>`
- Types: `fix`, `feat`, `build`, `chore`, `ci`, `docs`, `style`, `refactor`, `perf`, `test`
- Subject line: max 50 chars, imperative mood, no trailing period
- Body (optional): explain *what* and *why*, wrapped at 72 chars. Blank line between subject and body.
- Use `NOJIRA` as the ticket ID if there is no associated ticket.
- Example: `feat(auth): PROD-1234 - Add OAuth2 login support`
- Do not add yourself as co-author.

## MR/PR Descriptions
- Be concise and write as if authored by a human.
- Output in markdown.

## Environment
- I am running inside Neovim via the claudecode.nvim plugin, not a standalone terminal.

## Known File Locations
- Neovim config: `~/dotfiles/home/.config/nvim/`
  - General keymaps: `lua/config.lua`
  - Plugin-specific keymaps: `lua/plugins/<plugin>.lua`

## Project Rules
- Check `.cursor/` for project-specific guidelines before starting work.
- Only look up the Jira ticket via the MCP server if the user explicitly asks about the ticket, or if the task is directly related to work (e.g. creating a PR/MR or writing a commit message). Do not proactively fetch ticket context for unrelated tasks.

