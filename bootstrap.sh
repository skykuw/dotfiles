#!/usr/bin/env bash
# Bootstrap dotfiles on a new machine (macOS or Linux).
# Idempotent: safe to re-run.
#
# Usage: ./bootstrap.sh --profile=<profile>
#   <profile> is a file under templates/claude-settings/ without the .json.template
#   suffix. Discover available profiles with: ./bootstrap.sh --help

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

# --- Profile handling --------------------------------------------------------
# The Claude Code profile controls which ~/.claude/settings.json template is
# seeded. Required on every run (no default) so the choice is always explicit
# in shell history and CI logs.

list_profiles() {
  if [[ -d "$DOTFILES_DIR/templates/claude-settings" ]]; then
    (cd "$DOTFILES_DIR/templates/claude-settings" && \
      find . -type f -name '*.json.template' ! -name '*.local.json.template' \
        | sed -e 's|^\./||' -e 's|\.json\.template$||' \
        | sort)
  fi
}

PROFILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile=*) PROFILE="${1#--profile=}"; shift ;;
    --profile)   PROFILE="${2:-}"; shift 2 ;;
    -h|--help)
      cat <<EOF
Usage: $0 --profile=<profile>

Seeds ~/.claude/settings.json from templates/claude-settings/<profile>.json.template
and sets up the rest of the dotfiles.

Available profiles:
$(list_profiles | sed 's/^/  - /')

Examples:
  $0 --profile=personal
  $0 --profile=work/polaris
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 64
      ;;
  esac
done

if [[ -z "$PROFILE" ]]; then
  {
    echo "Error: --profile is required."
    echo ""
    echo "Available profiles:"
    list_profiles | sed 's/^/  - /'
    echo ""
    echo "Example: $0 --profile=personal"
  } >&2
  exit 64
fi

CLAUDE_PROFILE_TEMPLATE="$DOTFILES_DIR/templates/claude-settings/${PROFILE}.json.template"
if [[ ! -f "$CLAUDE_PROFILE_TEMPLATE" ]]; then
  {
    echo "Error: profile '$PROFILE' not found."
    echo "Expected template at: $CLAUDE_PROFILE_TEMPLATE"
    echo ""
    echo "Available profiles:"
    list_profiles | sed 's/^/  - /'
  } >&2
  exit 64
fi

echo "==> Using Claude profile: $PROFILE"

# --- OS detection ------------------------------------------------------------

OS="$(uname -s)"

# --- Package install helper --------------------------------------------------
# Usage: pkg_install <pkg-darwin> <pkg-apt> <pkg-dnf> <pkg-pacman> <pkg-zypper> <pkg-apk>
# Skips if the corresponding command is already on PATH (uses arg 1 as the
# canonical command name; pass an explicit CHECK= override before the name to
# disambiguate when the binary differs from the package name).

pkg_install() {
  local check="$1"; shift
  local mac_pkg="$1" apt_pkg="$2" dnf_pkg="$3" pacman_pkg="$4" zypper_pkg="$5" apk_pkg="$6"

  if command -v "$check" >/dev/null 2>&1; then
    echo "  -> $check already installed"
    return
  fi

  case "$OS" in
    Darwin)
      if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew not found. Install from https://brew.sh first." >&2
        exit 1
      fi
      brew install "$mac_pkg"
      ;;
    Linux)
      if   command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y "$apt_pkg"
      elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y "$dnf_pkg"
      elif command -v yum     >/dev/null 2>&1; then sudo yum install -y "$dnf_pkg"
      elif command -v pacman  >/dev/null 2>&1; then sudo pacman -S --needed --noconfirm "$pacman_pkg"
      elif command -v zypper  >/dev/null 2>&1; then sudo zypper install -y "$zypper_pkg"
      elif command -v apk     >/dev/null 2>&1; then sudo apk add --no-cache "$apk_pkg"
      else
        echo "No supported package manager found. Install '$check' manually." >&2
        exit 1
      fi
      ;;
    *)
      echo "Unsupported OS: $OS. Install '$check' manually." >&2
      exit 1
      ;;
  esac
}

# --- Install dependencies ----------------------------------------------------
# Args:                check    darwin    apt        dnf        pacman    zypper   apk
echo "==> Installing core dependencies"
pkg_install           stow      stow      stow       stow       stow      stow     stow
pkg_install           nvim      neovim    neovim     neovim     neovim    neovim   neovim
pkg_install           rg        ripgrep   ripgrep    ripgrep    ripgrep   ripgrep  ripgrep
# Note: on Debian/Ubuntu the `fd` binary is named `fdfind`. Symlink/alias if you want plain `fd`.
pkg_install           fd        fd        fd-find    fd-find    fd        fd       fd
pkg_install           tmux      tmux      tmux       tmux       tmux      tmux     tmux
# Required by claude/.claude/statusline.sh for JSON parsing
pkg_install           jq        jq        jq         jq         jq        jq       jq

# --- Optional: Brewfile (macOS only, kept for parity if you add casks etc.) -

if [[ "$OS" == "Darwin" ]] && command -v brew >/dev/null 2>&1 && [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
  echo "==> Reconciling Brewfile (covers anything not handled above)"
  brew bundle --file="$DOTFILES_DIR/Brewfile"
fi

# --- Stow packages -----------------------------------------------------------

# Each top-level directory (other than these) is a stow package.
EXCLUDES=(.git Brewfile Brewfile.lock.json README.md bootstrap.sh .gitignore templates)

echo "==> Stowing packages into $HOME"
for pkg in */; do
  pkg="${pkg%/}"
  skip=false
  for ex in "${EXCLUDES[@]}"; do
    [[ "$pkg" == "$ex" ]] && skip=true && break
  done
  $skip && continue
  echo "  -> $pkg"
  stow --restow --target="$HOME" "$pkg"
done

# --- Install TPM (tmux plugin manager) and plugins --------------------------

if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  echo "==> Installing TPM (tmux plugin manager)"
  git clone --quiet https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

if [[ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]] && [[ -f "$HOME/.tmux.conf" ]]; then
  echo "==> Installing tmux plugins via TPM"
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null
fi

# --- Install oh-my-zsh -------------------------------------------------------
# Run AFTER stow: KEEP_ZSHRC=yes preserves the symlinked ~/.zshrc that stow
# just placed, so the omz installer doesn't replace it with its template.

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "==> Installing oh-my-zsh"
  if ! command -v zsh >/dev/null 2>&1; then
    echo "zsh not found; install it via your package manager and re-run." >&2
  else
    RUNZSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  fi
else
  echo "==> oh-my-zsh already installed"
fi

# --- Seed local-only template files if missing ------------------------------
# Files like ~/.gitconfig.local and ~/.ssh/config.local hold identity and
# host-specific bits that don't belong in the repo. On a fresh machine, drop a
# template in place so the user has something to edit. Existing files are
# never touched.

seed_template() {
  local template="$1" dest="$2"
  if [[ ! -e "$dest" && -f "$template" ]]; then
    local parent; parent="$(dirname "$dest")"
    mkdir -p "$parent"
    # SSH demands ~/.ssh be 700; safe to enforce only on that specific dir.
    # Don't blindly chmod $parent — that would mangle $HOME's permissions.
    [[ "$parent" == "$HOME/.ssh" ]] && chmod 700 "$parent"
    install -m 400 "$template" "$dest"
    echo "==> Created $dest from template — edit it with your details (chmod u+w to unlock)"
  fi
}

seed_template "$DOTFILES_DIR/templates/gitconfig.local.template"  "$HOME/.gitconfig.local"
seed_template "$DOTFILES_DIR/templates/ssh-config.local.template" "$HOME/.ssh/config.local"

# --- Seed Claude Code settings from the chosen profile ----------------------
# Unlike gitconfig/ssh, this file gets 600 (read-write owner) because Claude
# Code may rewrite it when the user changes settings via /config or the UI.
# Clean up any dangling symlink from the older layout where settings.json was
# part of the stowed `claude` package.

if [[ -L "$HOME/.claude/settings.json" && ! -e "$HOME/.claude/settings.json" ]]; then
  echo "==> Removing dangling symlink at ~/.claude/settings.json (legacy stowed layout)"
  rm "$HOME/.claude/settings.json"
fi

if [[ ! -e "$HOME/.claude/settings.json" ]]; then
  mkdir -p "$HOME/.claude"
  install -m 600 "$CLAUDE_PROFILE_TEMPLATE" "$HOME/.claude/settings.json"
  echo "==> Seeded ~/.claude/settings.json from profile '$PROFILE'"
else
  echo "==> ~/.claude/settings.json already exists; leaving it alone (delete it to re-seed)"
  if ! diff -q "$CLAUDE_PROFILE_TEMPLATE" "$HOME/.claude/settings.json" >/dev/null 2>&1; then
    echo "    It differs from the '$PROFILE' template. To inspect:"
    echo "      diff '$CLAUDE_PROFILE_TEMPLATE' '$HOME/.claude/settings.json'"
    echo "    Tip: keep org/proxy-specific overrides in ~/.claude/settings.local.json"
    echo "    so you can re-seed settings.json without losing them."
  fi
fi

# Optional per-profile settings.local.json skeleton — for org/proxy bits that
# must not live in the dotfiles repo. Only seeds if the profile ships a
# *.local.json.template and the destination doesn't already exist. Mode 600
# because Claude Code may rewrite it.
CLAUDE_PROFILE_LOCAL_TEMPLATE="$DOTFILES_DIR/templates/claude-settings/${PROFILE}.local.json.template"
if [[ -f "$CLAUDE_PROFILE_LOCAL_TEMPLATE" && ! -e "$HOME/.claude/settings.local.json" ]]; then
  install -m 600 "$CLAUDE_PROFILE_LOCAL_TEMPLATE" "$HOME/.claude/settings.local.json"
  echo "==> Seeded ~/.claude/settings.local.json from profile '$PROFILE'"
  echo "    Edit it with your proxy URL / auth token / etc. before next Claude run."
fi

echo "==> Done."
