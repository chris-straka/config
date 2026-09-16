eval "$(/Users/c/.local/bin/mise activate zsh)"
# NOTE: no shims dir on PATH -- `mise activate` already handles shims.
# (Old line kept in ~/.zshrc.bak.20260912 if anything non-interactive misses it.)

# Go tools (gopls, gofumpt, dlv) are `go install`ed here, not via Mason:
# Mason runs `go` through mise's shim, which drops GOBIN, so its Go installs
# always misfire. Plain `go install <pkg>` in any shell lands here too.
export PATH="$HOME/go/bin:$PATH"

# history: large, shared across sessions, no dupes
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt append_history share_history hist_ignore_all_dups hist_reduce_blanks

# completion: cache + case-insensitive matching (built-in, no plugins needed)
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.zsh_cache"
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# opencode
export PATH=/Users/c/.opencode/bin:$PATH

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/c/.lmstudio/bin"
# End of LM Studio CLI section

# bun completions
[ -s "/Users/c/.bun/_bun" ] && source "/Users/c/.bun/_bun"
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/c/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions

export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator
export ANDROID_NDK_HOME=$HOME/Library/Android/sdk/ndk/30.0.16138531

# pnpm
export PNPM_HOME='/Users/c/Library/pnpm'
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

# mr: resume a Muse Code session without retyping flags.
# Usage: mr <session-id>  (bare mr resumes the last session)
mr() {
  if [ -n "$1" ]; then muse resume "$1" --yolo; else muse resume --last --yolo; fi
}

# mc: start a Muse Code session with --yolo (approval + sandbox bypassed).
# Usage: mc [muse args...]  (args pass through, e.g. mc "fix the build")
mc() {
  muse --yolo "$@"
}

# prompt: `c@z ~ %` shape — user@host white, directory mauve, dimmed %
# (mauve moved from the username to the path on request)
PROMPT='%F{#FFFFFF}%n@%m%f %F{#CBA6F7}%1~%f %F{#6C7086}%#%f '

export NARGO_HOME="/Users/c/.nargo"

export PATH="$PATH:$NARGO_HOME/bin"
export PATH="${HOME}/.bb:${PATH}"
export PATH="/Users/c/.bb:$PATH"
