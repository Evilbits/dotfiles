#!/bin/bash
# Links everything in home/ to ~/
# Files are symlinked directly; directories are created and their contents symlinked.

DG="\033[90m" # Dark grey
GR="\033[32m" # Green
OR="\033[33m" # Brown/Orange
NC="\033[0m"  # No color

DOTFILES_HOME="$(pwd)/home"

symlink() {
  ln -nsf "$1" "$2"
}

process() {
  local path="$1" target="$2" display="$3"

  if [[ -h "$target" && "$(readlink "$target")" == "$path" ]]; then
    echo -e "${DG}$display is symlinked to your dotfiles.${NC}"
  elif [[ -e "$target" ]] && cmp -s "$path" "$target" 2>/dev/null; then
    echo -e "${GR}$display is identical. Overriding with symlink.${NC}"
    symlink "$path" "$target"
  elif [[ -e "$target" || -h "$target" ]]; then
    read -rp "$(echo -e "${OR}$display differs from your dotfile. Override? [yn] ${NC}")" -n 1
    echo
    [[ $REPLY =~ [yY] ]] && symlink "$path" "$target"
  else
    echo -e "${GR}$display does not exist. Symlinking to dotfile.${NC}"
    symlink "$path" "$target"
  fi
}

for item in "$DOTFILES_HOME"/.[^.]*; do
  [[ -e "$item" ]] || continue
  name=$(basename "$item")

  if [[ -d "$item" ]]; then
    # If already symlinked as a whole directory, leave it alone
    if [[ -h "$HOME/$name" && "$(readlink "$HOME/$name")" == "$item" ]]; then
      echo -e "${DG}~/$name is symlinked as a whole directory.${NC}"
      continue
    fi
    # Create the directory in ~/ and symlink its contents one level deep
    mkdir -p "$HOME/$name"
    for subitem in "$item"/[^.]* "$item"/.[^.]*; do
      [[ -e "$subitem" ]] || continue
      subname=$(basename "$subitem")
      process "$subitem" "$HOME/$name/$subname" "~/$name/$subname"
    done
  else
    process "$item" "$HOME/$name" "~/$name"
  fi
done

# Uncomment if you need to remove a stale config not managed by this script:
# rm -rf ~/.config/alacritty
