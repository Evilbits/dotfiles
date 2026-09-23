#!/bin/sh
# Mirror the cockpit plugin from the company marketplace checkout into this public repo,
# swapping the picker screenshot for the redacted one. Run after changes land in
# doxyme/cooks/claude-plugins: ./scripts/sync-cockpit.sh [path-to-claude-plugins-checkout]
set -e
src="${1:-$HOME/dev/claude-plugins}/plugins/cockpit"
dst="$(cd "$(dirname "$0")/.." && pwd)/plugins/cockpit"
rm -rf "$dst"
mkdir -p "$dst"
cp -R "$src"/. "$dst"/
find "$dst" -name '__pycache__' -type d -prune -exec rm -rf {} +
cp "$(dirname "$0")/../plugins/redacted/picker.png" "$dst/docs/picker.png"
# This repo is a marketplace of its own, so the copy installs without the company one, and the
# company's GitLab paths in the examples become generic ones.
sed -i '' \
  -e 's#^/plugin marketplace add git@gitlab.com:doxyme/cooks/claude-plugins.git$#/plugin marketplace add https://github.com/Evilbits/dotfiles#' \
  -e 's#^/plugin install cockpit@doxyme$#/plugin install cockpit@rasmus#' \
  -e 's#https://gitlab.com/doxyme/[A-Za-z0-9_./-]*/-/merge_requests/#https://gitlab.com/acme/app/-/merge_requests/#g' \
  "$dst/README.md"
echo "synced $src -> $dst"
