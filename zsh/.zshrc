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

# --- CLI tool integrations -----------------------------------------------------
# Each line is guarded by `command -v` so the rc stays portable to machines
# that don't have the tool installed yet (e.g. before bootstrap runs).

# zoxide: `z <partial>` jumps to most-frecent matching directory. Keep `cd` intact.
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh --cmd z)"

# fzf: ctrl-r history, ctrl-t file picker, alt-c dir picker. Requires fzf >= 0.48.
command -v fzf >/dev/null 2>&1 && eval "$(fzf --zsh)"

# eza: replace `ls` with a git-aware, group-directories-first listing.
command -v eza >/dev/null 2>&1 && alias ls='eza --group-directories-first'

# --- Local overrides -----------------------------------------------------------
# Anything machine-specific or private (work paths, account info, secrets-ish
# aliases) goes in ~/.zshrc.local — that file is NOT in the dotfiles repo.

[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
