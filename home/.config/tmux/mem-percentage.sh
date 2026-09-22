#!/usr/bin/env bash
# Prints memory usage as an integer percentage, for tmux's status line.
#
# Replaces the macOS branch of GROG/tmux-plugin-mem, which reads the
# "compressor" field of `top -l 1` as if it were free memory. On a machine
# with no compression pressure that field is 0B, so the plugin computes
# 100*(total-0)/total and always reports 100. It also strips the G/M/B unit
# suffixes with sed, so its arithmetic mixes gigabytes and megabytes.
#
# vm_stat reports page counts against an explicit page size, so there are no
# units to lose. "Used" here excludes pages macOS can reclaim on demand:
# free, speculative (read-ahead cache) and inactive.

set -euo pipefail

stats=$(vm_stat)

page_size=$(sed -n 's/.*page size of \([0-9]*\) bytes.*/\1/p' <<<"$stats")
total_bytes=$(sysctl -n hw.memsize)

pages() {
  sed -n "s/^Pages $1: *\([0-9]*\)\./\1/p" <<<"$stats"
}

free_pages=$(( $(pages free) + $(pages speculative) + $(pages inactive) ))
free_bytes=$(( free_pages * page_size ))

printf '%d\n' $(( 100 * (total_bytes - free_bytes) / total_bytes ))
