#!/usr/bin/env bash
# Bootstrap dotfiles on a new machine (macOS or Linux).
# Idempotent: safe to re-run.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

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

# --- Optional: Brewfile (macOS only, kept for parity if you add casks etc.) -

if [[ "$OS" == "Darwin" ]] && command -v brew >/dev/null 2>&1 && [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
  echo "==> Reconciling Brewfile (covers anything not handled above)"
  brew bundle --file="$DOTFILES_DIR/Brewfile"
fi

# --- Stow packages -----------------------------------------------------------

# Each top-level directory (other than these) is a stow package.
EXCLUDES=(.git Brewfile Brewfile.lock.json README.md bootstrap.sh .gitignore)

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

echo "==> Done."
