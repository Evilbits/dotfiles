---
name: vibe-app-setup
description: >-
    Set up a Mac so someone outside engineering can build a doxy.me app with
    Claude: the code, the tools and the GitLab access, with the person never
    typing a command. Use when someone
    types /doxy:vibe-app-setup, says they want to get set up to vibe code an
    app, or when /doxy:vibe-app finds no doxyme-core checkout on the machine.
---

# /doxy:vibe-app-setup — a machine ready to build an app

The person has never used a terminal and does not know what any of these tools are. They are in the Claude Desktop app's Code tab, in a local session started in any folder (their home folder is fine). You run every command; they only do things in a browser and paste what they are asked for. Say what each step is for in one plain sentence before doing it, never ask them to type anything, and never explain a tool beyond what it does for them. Check before installing: nothing is assumed present, and nothing present is installed twice.

What the setup gives them, in their words: a copy of doxy.me's code on this Mac, the programs that build it, and permission to read and change that code. No doxy.me runs on this Mac; when they build an app later, the app skill sends the change to GitLab and gives them a link to a test environment where they see it running.

## 1 — What only they can do, asked first

One thing needs someone else at doxy.me, so ask about it before touching the machine and stop until it is there:

- **A GitLab account in the doxyme group** with access to the code. Ask: "Can you sign in at gitlab.com and open this page: https://gitlab.com/doxyme/code/doxyme-core ?" If they cannot sign in or the page says 404, an admin at doxy.me must add them; nothing else can start. Note their GitLab username for step 3.

Also needed, checked at the end: the GitLab and Atlassian connectors switched on in their claude.ai account (Settings → Connectors), since the app skill reads Jira and opens merge requests through them.

## 2 — The programs

An Apple Silicon Mac is assumed; say so if `uname -m` is not `arm64` and continue anyway. Each row: the check, then the install only when the check fails.

| Program, in their words | Check | Install |
| --- | --- | --- |
| The basic developer tools Apple provides | `xcode-select -p` | `xcode-select --install`, which opens a dialog the person clicks through; wait for it to finish, then check again |
| Homebrew, which installs the rest | `brew --version` | the one-line installer at https://brew.sh, then the two profile lines it prints, added to `~/.zprofile` |
| nvm, which gives the exact Node version the code wants | `ls ~/.nvm/nvm.sh` | `brew install nvm`, then the lines it prints for `~/.zshrc`, then open a new shell (`exec zsh`) |
| Node, the program that runs the build | `node --version` prints the version in the repo's `.nvmrc` | after the clone in step 4: `nvm install` in the checkout, then `nvm use`, and `nvm alias default <that version>` so every new shell has it |
| pnpm, which installs the code's dependencies | `pnpm --version` starts with `12` | `corepack enable` then `corepack prepare pnpm@12.1.0 --activate`; if corepack is missing, `npm i -g pnpm@12.1.0` |
| Git, which sends changes to GitLab | `git --version` | comes with the developer tools |

After any install that changes the shell profile, run the next commands in a fresh shell (`exec zsh` or `source ~/.zshrc`), or nothing installed is found.

## 3 — Permission to read and change the code

One token does everything; no SSH keys. Tell the person: "GitLab needs to know it is you when this Mac reads or sends code. It does that with a token, a long password you create once and paste here."

1. Send them this link: https://gitlab.com/-/user_settings/personal_access_tokens?name=doxyme-vibe&scopes=read_api,read_repository,write_repository . Tell them to press "Create personal access token" and paste the value that appears, once, into this conversation.
2. Store it three ways, then never print it again:
   - Git, so clone and push work: `git config --global credential.helper osxkeychain`, then feed the keychain with `printf 'protocol=https\nhost=gitlab.com\nusername=<gitlab username>\npassword=<token>\n' | git credential-osxkeychain store`.
   - The package registry, so `pnpm install` can fetch doxy.me's own packages: append `export GITLAB_NPM_TOKEN=<token>` to `~/.zshrc`, and `chmod 600 ~/.zshrc`. The repo's own `.npmrc` reads that variable.
   - Their name on commits: `git config --global user.name "<their name>"` and `git config --global user.email "<their doxy.me email>"`, asked once.
3. Check: `git ls-remote https://gitlab.com/doxyme/code/doxyme-core.git HEAD` prints one line. If it asks for a password or fails, the token or the group access is wrong; say which by the error, and go back one step.

## 4 — The code

```
git clone https://gitlab.com/doxyme/code/doxyme-core.git ~/doxyme-core
cd ~/doxyme-core && nvm install && nvm use && nvm alias default "$(cat .nvmrc)"
pnpm install
```

`pnpm install` takes several minutes the first time; say so. A `401` naming `@doxyme` means the token is not reaching the registry: check `echo $GITLAB_NPM_TOKEN` is non-empty in this shell, and that the token has `read_api`.

## 5 — The proof

This step checks the machine, not an app. `NX_DAEMON=false pnpm nx build extensions-notepad` builds one production app, Notepad, and in doing so uses everything the setup put in place: the complete checkout, the pinned Node and pnpm, the registry token (the build pulls doxy.me's own packages), and the build tooling. Green means the app skill's own lint, test and build will run on the person's app. Which app is built does not matter; Notepad is small and shipped. If it fails, read the error, name the cause in plain words and fix it; never ask the person to interpret it.

## 6 — Connectors, then hand over

Ask them to open claude.ai → Settings → Connectors and switch on GitLab and Atlassian, signing in to each. Without them the app skill cannot read the epic or open merge requests. Figma is optional and worth switching on if they use it.

Then, in one message: quit this session, start a new local session in the Code tab, choose the folder `~/doxyme-core` when it asks, and type the app skill's command. Everything from here is that skill.

## When it is already done

Every step checks before it acts, so running this again on a set-up machine changes nothing and ends at step 6. When only one thing is broken (a token expired, Node gone after an update), the failing check names it; fix that alone.
