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

What the setup gives them, in their words: a copy of doxy.me's code on this Mac, the programs that build it, permission to read and change that code, and a private doxy.me that runs on this Mac for trying an app out before anyone else sees it. When they build an app later, the app skill tests it on that private doxy.me, gives them links to try it themselves, and only then sends the change to GitLab.

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

1. Send them this link, with `<date>` replaced by the day three months from today as `YYYY-MM-DD` (`date -v+3m +%F`): `https://gitlab.com/-/user_settings/personal_access_tokens?name=doxyme-vibe&scopes=read_api,read_repository,write_repository&expires_at=<date>`. GitLab's own default is one month, which has run out on people mid-project; if the form shows a month anyway, ask them to set the expiry to that date before pressing "Create personal access token". Then they paste the value that appears, once, into this conversation.
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

`pnpm install` takes several minutes the first time; say so. A `401` naming `@doxyme` means the token is not reaching the registry: check `echo $GITLAB_NPM_TOKEN` is non-empty in this shell, and that the token has `read_api`. This install is what the generator and the lockfile need later; nothing on this Mac ever runs the app.

## 5 — The proof of the code

`pnpm install` finishing without an error is the proof: it means the checkout is complete, Node and pnpm are the right versions, and the registry token works, since the install pulls doxy.me's own packages. Nothing is built or tested here; the app skill leaves that to GitLab, which checks every change after it is sent. If the install fails, read the error, name the cause in plain words and fix it; never ask the person to interpret it.

## 6 — The private doxy.me

Tell the person: "Next is a private doxy.me that runs only on this Mac. When you build an app, it is tested there first, and you get links to try it yourself before anything is sent to the team." The tool is Blitz, doxy.me's own; its setup walk is the `blitz:setup` skill (loaded with the Skill tool) when this machine has the blitz plugin, and the README of the `@doxyme/blitz` package otherwise. Follow that walk; it checks before it installs and says what is left at every step. Four things about this person's machine that the walk does not know:

- **The registry.** Installing Blitz needs the `@doxyme` scope in `~/.npmrc` with the token from step 3 on its lines, as the walk's prerequisites table spells out. The token already has `read_api`; write those lines, never a second token.
- **GitLab over HTTPS, no SSH key.** The walk expects an SSH key; this person has the token in the keychain instead. Point Blitz at the HTTPS URLs through the environment variables the walk names for that case, in `~/.zshrc`. If `blitz doctor` still fails its `gitlab` row, make an SSH key for them (`ssh-keygen -t ed25519`), send them the public key to paste at gitlab.com/-/user_settings/ssh_keys, and check again. The account also needs access to `doxyme/cooks/hotpot`; a 404 there goes back to the admin from step 1.
- **The secrets come from a teammate.** The walk's first option, `blitz secrets sync`, needs AWS access the person does not have. Ask a teammate who runs Blitz to run `blitz secrets export` and send the file (a chat message to the engineer who set this up is fine). Save what arrives with mode 600, `blitz secrets import <file>`, delete the file, and never print a value. Until the file arrives, stop at this point; everything before it stands.
- **Two headless browsers**, which the app skill's tester uses so that it never needs the person's screen: the two Playwright MCP servers that `/doxy:blitz-test` step 0 sets up (copy its `playwright-mcp.json` to `~/.claude/doxy/`, `claude mcp add -s user doxy-provider …` and `doxy-patient …`, then `install-browser chromium`). They load on the next session, which step 7 starts anyway.

The proof is the walk's own: `blitz doctor` green, then a first stack that answers in the browser (`blitz first up`, the URL from its status). Open that URL for them so they see a doxy.me on their Mac, then `blitz first drop`; the app skill makes its own stack per app.

## 7 — Connectors, then hand over

Ask them to open claude.ai → Settings → Connectors and switch on GitLab and Atlassian, signing in to each. Without them the app skill cannot read the epic or open merge requests. Figma is optional and worth switching on if they use it.

Then, in one message: quit this session, start a new local session in the Code tab, choose the folder `~/doxyme-core` when it asks, and type the app skill's command. Everything from here is that skill.

## When it is already done

Every step checks before it acts, so running this again on a set-up machine changes nothing and ends at step 7. When only one thing is broken (a token expired, Node gone after an update, `blitz doctor` red after a Blitz update), the failing check names it; fix that alone.
