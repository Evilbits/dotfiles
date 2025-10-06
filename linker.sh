#!/bin/bash
# Links everything in home/ to ~/, does sanity checks.
# Based on the script by Simon Eskildsen (github.com/Sirupsen)

DG="\033[90m" # Dark grey
GR="\033[32m" # Green
OR="\033[33m" # Brown/Orange
NC="\033[0m" # No color

function symlink {
  ln -nsf $1 $2
}

function process() {
  if [[ -h $target && ($(readlink $target) == $path)]]; then
    echo -e "${DG}$baseFolder is symlinked to your dotfiles.${NC}"
  elif [[ -f $target && $(sha256sum $path | awk '{print $2}') == $(sha256sum $target | awk '{print $2}') ]]; then
    echo -e "${GR}$baseFolder exists and was identical to your dotfile.  Overriding with symlink.${NC}"
    symlink $path $target
  elif [[ -a $target ]]; then
    read -p "${OR}$baseFolder exists and differs from your dotfile. Override?  [yn]${NC}" -n 1

    if [[ $REPLY =~ [yY]* ]]; then
      symlink $path $target
    fi
  else
    echo -e "${GR}$baseFolder does not exist. Symlinking to dotfile.${NC}"
    symlink $path $target
  fi
}

for file in home/.[^.]*; do
  path="$(pwd)/$file"
  base=$(basename $file)
  baseFolder="~/$(basename $file)"
  target="$HOME/$(basename $file)"

  process
done

for file in home/.config/[^.]*; do
  path="$(pwd)/$file"
  base=$(basename $file)
  baseFolder="~/.config/$(basename $file)"
  target="$HOME/.config/$(basename $file)"

  process
done

#mkdir -p ~/.config/nvim
#ln -s ~/.vimrc ~/.config/nvim/init.vim
rm -rf ~/.config/alacritty # remove the config not linked by this

#echo "(1) sudo chsh -s /usr/local/bin/bash $(whoami)"
#echo "(1) Install plug"
#echo "(2) Run :PlugInstall in Vim"
