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
echo "synced $src -> $dst"
