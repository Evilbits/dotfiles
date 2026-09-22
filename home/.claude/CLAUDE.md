# Global Claude Instructions

## Safety
- Before running any command, briefly describe what it does.
- Before any destructive operation (deleting files, force pushes, dropping data, etc. — this list is not exhaustive), warn in bold and require explicit confirmation.
- Never push to a remote without explicit confirmation, with one standing exception: the hand-off step of `/doxy-implement` pushes the ticket branch and opens a draft MR without asking. Force-pushes still ask, always.

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
- When referencing keymaps, always look up the user's actual mappings from the config rather than assuming defaults.

## Project Rules
- Only look up the Jira ticket via the MCP server if the user explicitly asks about the ticket, or if the task is directly related to work (e.g. creating a PR/MR or writing a commit message). Do not proactively fetch ticket context for unrelated tasks.

## `.cursor/` Skills and Rules (override built-in superpowers)

In any repo containing a `.cursor/` directory, the contents of `.cursor/` are the authoritative process guide. This OVERRIDES the built-in `superpowers:*` skills.

### Skills
- When a task would normally trigger a `superpowers:<name>` skill (e.g. `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:test-driven-development`), first check `.cursor/skills/<name>/SKILL.md`. If it exists, Read that file and follow it as the active skill. Do NOT invoke the corresponding `superpowers:*` skill via the Skill tool.
- If `.cursor/skills/` contains a skill with no built-in equivalent (e.g. `doxyme-design-system`, `gitlab-merge-request`, `release-changelog`), treat it like any other skill — Read `.cursor/skills/<name>/SKILL.md` when the task matches its purpose.
- Announce usage the same way as built-in skills: "Using .cursor/skills/<name> to <purpose>".

### Rules
Rules are **colocated with the projects they describe**, so they live in nested folders, not only at the root. In doxyme-core: `.cursor/rules/` (cross-cutting), `apps/extensions/.cursor/rules/` (the Apps team rules — nine files, two of them alwaysApply), `apps/api-extensions/`, `apps/api-core/`, `apps/frontend/`, `libs/ui/`, `e2e/`, `docs/`. Cursor attaches a nested folder automatically when a file under it is touched; mirror that.

- At task start, glob **`**/.cursor/rules/*.mdc`** (excluding `node_modules/` and `.worktrees/`) once to see what exists, and read the frontmatter of each.
- Read every root-folder `.mdc` with `alwaysApply: true`. For a nested folder, read its `alwaysApply: true` files when the task touches anything under that folder's parent directory, or when the task is about that project's domain (an extension, the SDK, a capability, the bridge, Hotpot data) even if no file has been opened yet. `apps/extensions/.cursor/rules/00-sdk-guidelines.mdc` defines the SDK vocabulary (Bridge, Toolkit, Capability, App, Runtime, Actions, Events, Registry) and its `00-rule-interpretation.mdc` says how the Apps rules are to be applied — load both before any design or review conversation about extensions, apps, capabilities or the SDK.
- Read any other `.mdc` when its `globs` match a path being touched or its `description` matches the task (e.g. read `test-commands.mdc` before running tests).
- Treat loaded rules as binding standards for the rest of the session. If a rule turns out to be missing context or wrong, say so and propose the fix to the rule file itself rather than working around it.

