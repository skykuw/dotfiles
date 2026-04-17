# dotfiles

Personal config managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Layout

Each top-level directory is a **stow package** — its contents mirror the layout
of `$HOME` and get symlinked into place.

```
dotfiles/
├── claude/                  # package: Claude Code config
│   └── .claude/
│       ├── CLAUDE.md        # global instructions for all projects
│       ├── settings.json    # attribution, permissions, hooks, etc.
│       └── skills/
│           ├── code-review-author/
│           ├── diagnose-codebase/
│           └── pragmatic-programmer/
├── nvim/                    # package: Neovim config (kickstart-style)
│   └── .config/
│       └── nvim/
│           ├── init.lua
│           └── lua/
│               └── plugins/
│                   └── init.lua
├── zsh/                     # package: zsh config (oh-my-zsh based)
│   ├── .zshrc               # universal — sources ~/.zshrc.local at end
│   └── .zprofile            # universal — conditional MacPorts PATH
├── tmux/                    # package: tmux config + TPM plugins
│   └── .tmux.conf
├── iterm2/                  # package: iTerm2 prefs (macOS only)
│   └── .config/iterm2/
│       └── com.googlecode.iterm2.plist
├── git/                     # package: git config (with local split)
│   └── .gitconfig
├── ssh/                     # package: SSH config (with local split)
│   └── .ssh/
│       └── config
├── templates/                       # placeholder configs seeded by bootstrap.sh
│   ├── gitconfig.local.template     #   → seeded to ~/.gitconfig.local if missing
│   └── ssh-config.local.template    #   → seeded to ~/.ssh/config.local if missing
├── Brewfile                 # tools required to bootstrap
├── bootstrap.sh             # idempotent installer
└── README.md
```

## Neovim (nvim package)

Single-file kickstart-style config (~80-line `init.lua` + ~150-line plugin
spec). On first launch, lazy.nvim self-bootstraps, installs all plugins, and
mason auto-installs LSP servers for Python, Go, Rust, Lua, and C/C++.

- Default colorscheme: **catppuccin** (mocha). Tokyonight is also installed —
  switch any time with `:colorscheme tokyonight`.
- Leader key: `<Space>`. `<leader>ff` find files, `<leader>fg` live grep,
  `<leader>e` toggle file tree.
- LSP keymaps (in any buffer with an LSP attached): `gd` go-to-def, `K` hover,
  `<leader>rn` rename, `<leader>ca` code action, `<leader>f` format.
- For C/C++ you'll need system clang headers — on macOS run
  `xcode-select --install` once if you haven't already.

## Zsh (zsh package)

Tracked `.zshrc` covers universal config: oh-my-zsh sourcing, theme
(`sonicradish`), `git` plugin, `EDITOR=nvim`, `~/.local/bin` on PATH. At the
end it sources `~/.zshrc.local` if present — that file lives outside the repo
and holds personal/machine-specific aliases, paths, secrets-ish content.

`bootstrap.sh` installs oh-my-zsh idempotently *after* stowing, so the omz
installer's `KEEP_ZSHRC=yes` mode preserves the symlinked `.zshrc` rather than
replacing it with the omz template.

## Tmux (tmux package)

`~/.tmux.conf` with sensible defaults (prefix `C-a`, mouse, vim-style pane
nav, intuitive `|`/`-` splits, 50k history) plus TPM plugins:
`tmux-sensible`, `tmux-resurrect`, `tmux-yank`, `vim-tmux-navigator`.

`bootstrap.sh` clones TPM if missing and runs `install_plugins` so plugins
materialize without needing `prefix + I` interactively.

Reload after editing: `prefix + r`. Inside tmux, install/update plugins with
`prefix + I` and `prefix + U`.

## iTerm2 (iterm2 package, macOS only)

The plist lives at `iterm2/.config/iterm2/com.googlecode.iterm2.plist` and
stows to `~/.config/iterm2/`. **One-time manual step on a fresh machine:**

iTerm2 → *Settings* → *General* → *Preferences* → check **"Load preferences
from a custom folder or URL"** → set folder to `~/.config/iterm2/` → also
check **"Save changes to folder when iTerm2 quits"** for bidirectional sync.

After that, every iTerm2 settings change syncs straight into the dotfiles
repo (binary plist, so no diffs — just commits).

> **Privacy:** the plist may contain SSH host nicknames, profile names, or
> anything you've configured in iTerm2's password manager. Review before
> publishing this repo.

## Git and SSH (git, ssh packages — tracked/local split)

Both use the same pattern as `zsh`: a tracked universal file + a local
read-only file for personal identity / machine-specific settings.

**Git:**
- `git/.gitconfig` (tracked) — `push.default`, `init.defaultBranch`, `pull.rebase`, then `[include] path = ~/.gitconfig.local`
- `~/.gitconfig.local` (**NOT tracked**, chmod 400) — `[user]` identity + `[credential] helper` (macOS-specific; change to `cache` or `libsecret` on Linux)

**SSH:**
- `ssh/.ssh/config` (tracked) — `Include ~/.ssh/config.local` at top, then `Host *` defaults (ServerAlive, AddKeysToAgent, UseKeychain)
- `~/.ssh/config.local` (**NOT tracked**, chmod 400) — per-host `IdentityFile` / `HostName` entries
- SSH's first-match-wins rule + putting `Include` at the top of the tracked file means local settings override defaults automatically

On a fresh machine, `bootstrap.sh` seeds `~/.gitconfig.local` and
`~/.ssh/config.local` from `templates/*.template` (chmod 400). Existing
files are never touched. Edit the seeded files with your real identity and
hosts; `chmod u+w` first since they're created read-only.

The templates use a `.template` suffix (not `.local`) so they're not caught
by the `*.local` rule in `.gitignore`.

To add a new bundle (e.g. zsh, git), create a sibling directory like `zsh/` with
the file structure mirroring `$HOME`, then re-run `bootstrap.sh`.

## Install on a new machine

```bash
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

This installs `stow` (via Homebrew on macOS, or the system package manager on
Linux — apt, dnf, yum, pacman, zypper, apk) and symlinks every package into
`$HOME`. The `Brewfile` is only consumed when `brew` is present.

## Add or remove a package manually

```bash
cd ~/dotfiles
stow claude            # symlink the claude package into $HOME
stow -D claude         # remove its symlinks
stow -R claude         # re-stow (refresh symlinks)
```

## Conflicts

If stow refuses because a real file already exists at the target, that file
isn't tracked here. Either move it into the matching package, delete it, or
add it to a `.stow-local-ignore` so stow skips it.

## What is *not* tracked

- `~/.claude/skills/graphify/` — intentionally left as a real directory in
  `$HOME`, not part of this repo.
- Anything matched by `.gitignore` (secrets, editor swap files, etc.).
