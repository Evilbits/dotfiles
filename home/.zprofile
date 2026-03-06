
# Cache brew shellenv to avoid running brew binary on every login shell
if command -v brew &>/dev/null; then
  if [[ ! -f ~/.zsh_brew_cache || ~/.zsh_brew_cache -ot $(command -v brew) ]]; then
    brew shellenv > ~/.zsh_brew_cache
  fi
  source ~/.zsh_brew_cache
fi
