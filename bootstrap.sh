#!/usr/bin/env bash
# Bootstrap dotfiles on a new machine (macOS or Linux).
# Idempotent: safe to re-run.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

# --- Install stow ------------------------------------------------------------

install_stow() {
  if command -v stow >/dev/null 2>&1; then
    echo "==> stow already installed ($(stow --version | head -1))"
    return
  fi

  case "$(uname -s)" in
    Darwin)
      if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew not found. Install from https://brew.sh first." >&2
        exit 1
      fi
      echo "==> Installing stow via Homebrew"
      brew install stow
      ;;
    Linux)
      echo "==> Installing stow via system package manager"
      if   command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y stow
      elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y stow
      elif command -v yum     >/dev/null 2>&1; then sudo yum install -y stow
      elif command -v pacman  >/dev/null 2>&1; then sudo pacman -S --needed --noconfirm stow
      elif command -v zypper  >/dev/null 2>&1; then sudo zypper install -y stow
      elif command -v apk     >/dev/null 2>&1; then sudo apk add --no-cache stow
      else
        echo "No supported package manager found (apt, dnf, yum, pacman, zypper, apk). Install stow manually." >&2
        exit 1
      fi
      ;;
    *)
      echo "Unsupported OS: $(uname -s). Install stow manually." >&2
      exit 1
      ;;
  esac
}

install_stow

# --- Optional: Brewfile (macOS only) ----------------------------------------

if command -v brew >/dev/null 2>&1 && [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
  echo "==> Installing Brewfile dependencies"
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
