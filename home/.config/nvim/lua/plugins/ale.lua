return {
  'w0rp/ale',
  enabled = false,
  config = function()
    vim.cmd([[
      " ====== Ale config ======
      " Set which linters to use
      let g:ale_linters = {'javascript': ['prettier', 'eslint'], 'python': ['mypy'] }
      let g:ale_fixers = ['prettier', 'eslint'] " Fix files with prettier, and then ESLint.
      let g:ale_fix_on_save = 1                 " Set this variable to 1 to fix files when you save them.
      let g:ale_disable_lsp = 1                 " Disable lsp as we use nvim native lsp
      let g:ale_set_highlights = 0              " Remove highlighting
      " Map different languages to above linters
      let g:ale_linter_aliases = {'typescript': 'javascript', 'typescriptreact': 'javascript'}
      " Automatic Typescript import from external modules
      let g:ale_completion_tsserver_autoimport = 1
      " Work with pipenv
      let g:ale_python_auto_poetry = 1
      
      " ====== GitMessenger config ======
      let g:git_messenger_always_into_popup = v:true
      let g:git_messenger_include_diff = "current"
    ]])
  end
}
