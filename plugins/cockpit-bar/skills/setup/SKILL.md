---
name: setup
description: >-
    Build and install the Cockpit Bar menu bar app from this plugin's source into ~/Applications and
    start it at login. Use when the user runs /cockpit-bar:setup, asks to install, rebuild or update
    the menu bar app, or after a plugin update when the app should pick up the new version.
allowed-tools: Bash(xcode-select *), Bash(${CLAUDE_PLUGIN_ROOT}/build.sh*), Bash(ls *), Bash(which *)
---

# /cockpit-bar:setup

1. Check the prerequisites: `xcode-select -p` must print a path (the Swift compiler comes with the Xcode Command Line Tools; `xcode-select --install` fetches them), `which node` must find Node (the hooks are Node scripts), and `~/.local/bin/cockpit` must exist (the app reads its rows through the cockpit plugin; `/cockpit:setup` installs it). Stop and say which one is missing.
2. Run `"${CLAUDE_PLUGIN_ROOT}/build.sh"`. It compiles the app, installs it as `~/Applications/Cockpit Bar.app`, writes a LaunchAgent so it starts at login, and launches it.
3. Relay the script's output as it is. The app appears in the menu bar within a second; sessions started from now on are tracked from their first prompt, sessions already open show without activity until they are restarted.

Re-run the same command after every `claude plugin update cockpit-bar@…`: the app is stamped with the path of the plugin version it was built from, and a build from the new folder is what moves it over.
