-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out,                            "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader              = " "
vim.g.maplocalleader         = "\\"
vim.g.startify_change_to_dir = 0   -- prevent startify from changing cwd on file open
vim.keymap.set("", "<Space>", "<Nop>", { silent = true })

require("lazy").setup({
  spec    = { { import = "plugins" } },
  install = { colorscheme = { "habamax" } },
  checker = { enabled = true },
})

-- Searching / jumping
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- Git
vim.keymap.set("n", "<leader>gs", "<cmd>Telescope git_status<CR>")
vim.keymap.set("n", "<leader>d",  "<cmd>Gitsigns diffthis<CR>")
vim.keymap.set("n", "<leader>gb", ":GitMessenger<CR>")
vim.keymap.set("n", "<leader>gB", ":Git blame<CR>")
-- Treesitter
vim.keymap.set("n", "<leader>t", "<cmd>Telescope treesitter<CR>")
-- CopilotChat
vim.keymap.set("n",           "<C-s>g", ":CopilotChatCommit<CR>")
vim.keymap.set({ "n", "v" }, "<C-s>c", ":CopilotChatToggle<CR>")
-- Terminal
vim.keymap.set("t", "<C-s><C-e>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
-- Misc
vim.keymap.set("n", "<leader>rr", vim.lsp.buf.rename)
vim.keymap.set("n", "<leader>z",  ":ZenMode<CR>")

-- ====== Options ======

vim.opt.scrolloff  = 10  -- Always keep x lines above/below cursor
vim.opt.updatetime = 50  -- Faster update

-- Diff: ensure exactly one context: entry
local _dopts = vim.opt.diffopt:get()
for i = #_dopts, 1, -1 do
  if _dopts[i]:match("^context:") then table.remove(_dopts, i) end
end
table.insert(_dopts, "context:30")
vim.opt.diffopt = _dopts

-- General
vim.opt.ttimeoutlen   = 100   -- Stops delay on 'O' after ESC
vim.opt.autoread      = true  -- Auto-reload file if changed externally
vim.opt.encoding      = "utf-8"
vim.opt.fileformats   = { "unix", "dos", "mac" }
vim.opt.undofile      = true  -- Persist undo history across sessions
vim.opt.backupdir     = vim.fn.expand("~/.config/nvim/tmp/backup")
vim.opt.directory     = vim.fn.expand("~/.config/nvim/tmp/swap")
vim.opt.undodir       = vim.fn.expand("~/.config/nvim/tmp/undo")
vim.opt.scrolljump    = 5
vim.opt.termguicolors = true
vim.opt.cursorline    = true
vim.opt.mouse         = ""
vim.opt.clipboard     = "unnamed"

-- Tabs
vim.opt.tabstop     = 2
vim.opt.shiftwidth  = 2
vim.opt.expandtab   = true
vim.opt.softtabstop = 0
vim.opt.autoindent  = true

-- Line numbers
vim.opt.number         = true
vim.opt.relativenumber = true