brew "stow"

# Neovim + tools for telescope/lsp/etc.
brew "neovim"
brew "ripgrep"
brew "fd"
brew "tmux"

# General CLI quality-of-life
brew "bat"            # syntax-highlighted `cat`
brew "btop"           # resource monitor / `top` replacement
brew "eza"            # modern `ls` with git status + tree
brew "fzf"            # fuzzy finder (powers shell widgets + git-recent helper)
brew "gh"             # GitHub CLI (personal use; work profile blocks via permissions)
brew "git-delta"      # syntax-highlighted git diffs (configured as core.pager)
brew "lazygit"        # TUI git client
brew "shellcheck"     # shell linter for any tracked .sh scripts
brew "zoxide"         # smart `cd` that learns frecent directories

# GUI apps (macOS only — Brewfile is gated to Darwin in bootstrap.sh)
cask "iterm2"

# Nerd Font — required by nvim's lualine/nvim-tree/web-devicons and used by
# the Claude Code statusline icons (CLAUDE_STATUSLINE_ICONS=1 by default;
# set to 0 to fall back to text labels). tmux (catppuccin v0.3.0) and zsh
# (sonicradish) don't depend on it — they use standard Unicode glyphs.
cask "font-jetbrains-mono-nerd-font"
