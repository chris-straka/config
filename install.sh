#!/usr/bin/env bash
# Installs this config repo onto a machine by symlinking into place.
# Idempotent: existing symlinks that already point here are left alone,
# real files are backed up with a timestamp before being replaced.
# New machine: clone https://github.com/chris-straka/config.git ~/config,
# then run ~/config/install.sh (restart Ghostty after, for window chrome).
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() { # link <path-in-repo> <target-path>
  local src="$REPO/$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok:   $dst"
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    local bak="$dst.pre-config-$(date +%Y%m%d%H%M%S)"
    echo "backup: $dst -> $bak"
    mv "$dst" "$bak"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "link: $dst -> $src"
}

sync_ghostty() { # splice shared-keybinds.conf into config + nvim-launcher
  # (idempotent: re-running on already-generated files is a no-op).
  # Both files must work standalone — the Spotlight launcher handoff
  # drops `config-file` includes — so the shared Cmd-key block lives in
  # exactly one place and gets copied into both markers below.
  local shared="$REPO/ghostty/shared-keybinds.conf"
  local begin='# <<SHARED-KEYBINDS-BEGIN'
  local end='# <<SHARED-KEYBINDS-END>>'
  local body
  body="$(tail -n +8 "$shared")" # strip the 7-line editing header
  for f in "$REPO/ghostty/config" "$REPO/ghostty/nvim-launcher"; do
    local tmp="$f.tmp.$$"
    awk -v begin="$begin" -v end="$end" -v body="$body" '
      index($0, begin) { print; print body; skip = 1; next }
      index($0, end) { skip = 0 }
      !skip { print }
    ' "$f" > "$tmp" && mv "$tmp" "$f"
    rm -f "$tmp"
    echo "sync: $f"
  done
}

sync_ghostty
link nvim "$HOME/.config/nvim"
link ghostty "$HOME/.config/ghostty"
link muse/settings.json "$HOME/.config/muse/settings.json"
link zsh/.zshrc "$HOME/.zshrc"
link zsh/.zprofile "$HOME/.zprofile"
link git/.gitconfig "$HOME/.gitconfig"
echo done.
