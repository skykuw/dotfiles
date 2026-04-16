# dotfiles

Personal config managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Layout

Each top-level directory is a **stow package** — its contents mirror the layout
of `$HOME` and get symlinked into place.

```
dotfiles/
├── claude/                  # package: Claude Code config
│   └── .claude/
│       └── skills/
│           ├── code-review-author/
│           ├── diagnose-codebase/
│           └── pragmatic-programmer/
├── Brewfile                 # tools required to bootstrap
├── bootstrap.sh             # idempotent installer
└── README.md
```

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
