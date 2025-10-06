export ZSH="${ZSH:-$HOME/.oh-my-zsh}"

ZSH_THEME='common'
# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# zsh-syntax-highligting
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=11'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=11'
ZSH_HIGHLIGHT_STYLES[arg0]='fg=11'

# spaceship theme settings
SPACESHIP_USER_SHOW='always'
SPACESHIP_BATTERY_SHOW=false
SPACESHIP_RUBY_SYMBOL=''
SPACESHIP_PROMPT_ADD_NEWLINE=true

SPACESHIP_PROMPT_ORDER=(
  # time        # Time stamps section (Disabled)
  user          # Username section
  dir           # Current directory section
  host          # Hostname section
  git           # Git section (git_branch + git_status)
  hg            # Mercurial section (hg_branch  + hg_status)
  # package     # Package version (Disabled)
  node          # Node.js section
  ruby          # Ruby section
  elixir        # Elixir section
  # xcode       # Xcode section (Disabled)
  swift         # Swift section
  golang        # Go section
  php           # PHP section
  rust          # Rust section
  haskell       # Haskell Stack section
  # julia       # Julia section (Disabled)
  # docker      # Docker section (Disabled)
  aws           # Amazon Web Services section
  venv          # virtualenv section
  conda         # conda virtualenv section
  pyenv         # Pyenv section
  dotnet        # .NET section
  # ember       # Ember.js section (Disabled)
  kubecontext   # Kubectl context section
  terraform     # Terraform workspace section
  exec_time     # Execution time
  line_sep      # Line break
  battery       # Battery level and status
  # vi_mode     # Vi-mode indicator (Disabled)
  jobs          # Background jobs indicator
  exit_code     # Exit code section
  char          # Prompt character
)

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=60'

alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias -g G='| grep'
alias grep="grep --color=auto"

# git aliases
alias g='git'

alias tmux='tmux -2'

# Always use xterm for SSH
alias ssh='TERM=xterm-256color ssh'

# Kubernetes
alias kubegp='kubectl get pods'
alias kubegd='kubectl get deployments'
alias kubegs='kubectl get service'
alias kubegi='kubectl get ingress'
alias kubelf="kubectl logs -f"
alias kubedp='kubectl describe pod'
alias kubedd='kubectl describe deployment'
alias kubeds='kubectl describe servier'
alias kubedi='kubectl describe ingress'

export EDITOR=nvim

# Source custom fzf widgets
source /Users/rasmusreiler/.config/fzf/key-bindings.zsh
source "$HOME/.config/fzf/key-bindings.zsh"
export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow --glob "!.git/*" --glob "!node_modules/*"'
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

bindkey '^r' fzf-history-widget # CTRL-r - Search history
bindkey '\ec' fzf-cd-widget     # ALT-c  - Deep cd using fzf
bindkey -s '^b' "git branch | fzf --height=20% --reverse --info=inline | awk '{print $1}' | xargs git checkout^M"

# Add custom scripts
export PATH=$PATH:~/scripts

# Load in extra env that we don't want to store in Git
if [ -f ~/.env ]; then
    . ~/.env
fi

alias vim="nvim"

# Stops zsh from correcting arguments
unsetopt correct_all  
setopt correct

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

alias nx="pnpm nx"
