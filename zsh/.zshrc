# ~/.zshrc — universal shell config (tracked in dotfiles)
# Personal/machine-specific settings belong in ~/.zshrc.local (sourced at end).

# --- oh-my-zsh -----------------------------------------------------------------

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="sonicradish"
plugins=(git)

# Only source omz if it's actually installed (bootstrap.sh installs it on a fresh machine).
[[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# --- Editor --------------------------------------------------------------------

export EDITOR='nvim'
export VISUAL='nvim'

# --- PATH ----------------------------------------------------------------------

export PATH="$HOME/.local/bin:$PATH"

# --- Local overrides -----------------------------------------------------------
# Anything machine-specific or private (work paths, account info, secrets-ish
# aliases) goes in ~/.zshrc.local — that file is NOT in the dotfiles repo.

[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
