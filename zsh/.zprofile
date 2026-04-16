# ~/.zprofile — login shell init (tracked in dotfiles)

# MacPorts: only prepend if installed (no-op on Linux or systems without MacPorts)
[[ -d /opt/local/bin ]] && export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
