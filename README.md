# dotfiles

Personal config managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Layout

Each top-level directory is a **stow package** — its contents mirror the layout
of `$HOME` and get symlinked into place.

```
dotfiles/
├── claude/                  # package: Claude Code shared config
│   └── .claude/
│       ├── CLAUDE.md        # global instructions for all projects
│       ├── statusline.sh    # status-bar renderer (profile, model, ctx, $)
│       └── skills/          # shared across machines via git
│           ├── code-review-author/
│           ├── diagnose-codebase/
│           └── pragmatic-programmer/
│       # settings.json is NOT here — it's per-machine, seeded from
│       # templates/claude-settings/ by bootstrap.sh based on --profile
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
│   ├── ssh-config.local.template    #   → seeded to ~/.ssh/config.local if missing
│   └── claude-settings/             # per-machine Claude Code profiles
│       ├── personal.json.template   #   --profile=personal
│       └── work/
│           └── polaris.json.template #  --profile=work/polaris
├── Brewfile                 # tools required to bootstrap
├── bootstrap.sh             # idempotent installer (takes --profile=<name>)
├── claude-sync.sh           # pull + re-stow claude package (for consumer machines)
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

## Claude Code (claude package + profiles)

The `claude/` package carries the **shared** parts of Claude Code config:
`CLAUDE.md` and `skills/`. These are committed and travel to every machine.

The per-machine parts — model choice, thinking/effort, permission scope —
live in `~/.claude/settings.json`, which is **not** in the stowed tree.
Instead, `bootstrap.sh --profile=<name>` seeds it from
`templates/claude-settings/<name>.json.template` on a fresh machine.

Two profiles ship today:

- `personal` — Opus default, `alwaysThinkingEnabled: true`, `effortLevel: high`,
  showing thinking summaries. Used on the machine where new skills are
  developed.
- `work/<codename>` — Sonnet default, thinking off, `effortLevel: medium`.
  Cost-conscious for a machine with a daily spend cap. `work/polaris` is the
  current entry. Add new codenames (stars) as new employers appear.

Both profiles share the same lean read-only permission allowlist and a
no-attribution override; differences are in model and cost levers.

Each profile's `statusLine` calls `~/.claude/statusline.sh <profile>`, which
renders a two-line status at the bottom of Claude Code:

```
[personal] Opus 4.7  main*  $0.04  1m32s
ctx 15.5k/1.0M 2%  cache 3:20  5h 12%  7d 34%
```

Line 1 is identity + session totals; line 2 is pressure gauges.

- **Tag** (`[personal]` / `[work/polaris]`) — green for personal, yellow for work.
- **Git branch** — dim when clean, yellow with `*` when dirty. Omitted when cwd isn't a git repo.
- **Context** — dim under 50%, yellow 50–80%, red ≥80%.
- **Cache** — Anthropic prompt-cache TTL countdown (default 5 min). Dim above 1 min, yellow under 1 min, red `cold` once expired. Tracked via a sidecar file (`~/.claude/.statusline_state`) keyed on `session_id` + `total_api_duration_ms`, so refresh ticks don't fake a reset.
- **Rate limits** — 5-hour and 7-day windows. Dim under 50%, yellow 50–80%, red ≥80%. The leading signal that the work budget is about to cut you off.

`refreshInterval: 5` keeps the cache countdown ticking during idle. The
script runs locally (no tokens). Requires `jq` (installed by bootstrap).

**Install the profile on a fresh machine:**

```bash
./bootstrap.sh --profile=personal
# or
./bootstrap.sh --profile=work/polaris
```

`--profile=` is required on every run so the choice stays explicit in shell
history. Run `./bootstrap.sh --help` to list available profiles. The seed is
idempotent — it won't overwrite an existing `~/.claude/settings.json` (delete
it first to re-seed).

**Sync skills from the personal machine to work:**

```bash
./claude-sync.sh
```

Fast-forwards the dotfiles repo and re-stows the `claude` package. This is how
new skills developed on personal flow to work once pushed to GitHub — no need
to re-run the full bootstrap.

## Install on a new machine

```bash
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
./bootstrap.sh --profile=personal      # or --profile=work/<codename>
```

This installs `stow` (via Homebrew on macOS, or the system package manager on
Linux — apt, dnf, yum, pacman, zypper, apk), symlinks every package into
`$HOME`, and seeds the per-machine Claude settings from the chosen profile.
The `Brewfile` is only consumed when `brew` is present.

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
