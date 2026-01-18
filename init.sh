#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

log() { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!!\033[0m %s\n" "$*" >&2; }
die() { printf "\033[1;31mxx\033[0m %s\n" "$*" >&2; exit 1; }

# ----------------------------------------
# Homebrew
# ----------------------------------------
ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    log "Homebrew: already installed"
    return
  fi

  if [[ "$OS" != "Darwin" ]]; then
    die "Homebrew not found and OS is not macOS (uname=$OS). Install brew manually."
  fi

  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # brew のパスを通す（Apple Silicon / Intel 両対応）
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

brew_bundle() {
  local brewfile="$DOTFILES_DIR/homebrew/Brewfile"
  if [[ ! -f "$brewfile" ]]; then
    warn "Brewfile not found: $brewfile (skip brew bundle)"
    return
  fi

  log "Brew bundle install (Brewfile)"
  brew bundle --file "$brewfile"
}

# ----------------------------------------
# Symlink helper
# ----------------------------------------
backup_and_link() {
  local src="$1"
  local dst="$2"

  # すでに同じリンクなら何もしない
  if [[ -L "$dst" ]]; then
    local cur
    cur="$(readlink "$dst" || true)"
    if [[ "$cur" == "$src" ]]; then
      log "Link exists: $dst -> $src"
      return
    fi
  fi

  # 既存があれば退避（ディレクトリ/ファイルどちらでも）
  if [[ -e "$dst" || -L "$dst" ]]; then
    local ts
    ts="$(date +"%Y%m%d-%H%M%S")"
    local backup="${dst}.bak.${ts}"
    warn "Backup: $dst -> $backup"
    mv "$dst" "$backup"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  log "Linked: $dst -> $src"
}

# ----------------------------------------
# Link plan
# ----------------------------------------
link_all() {
  log "Creating base dirs"

  # Ghostty
  backup_and_link "$DOTFILES_DIR/ghostty/config" "$HOME/.config/ghostty/config"

  # Git
  backup_and_link "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"

  # Hammerspoon
  backup_and_link "$DOTFILES_DIR/hammerspoon/init.lua" "$HOME/.hammerspoon/init.lua"

  # Zsh
  backup_and_link "$DOTFILES_DIR/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
  backup_and_link "$DOTFILES_DIR/zsh/.zprofile" "$HOME/.zprofile"
  backup_and_link "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"

  # Rectangle
  backup_and_link "$DOTFILES_DIR/rectangle/RectangleConfig.json" "$HOME/Library/Application Support/Rectangle/RectangleConfig.json"
}

# ----------------------------------------
# Main
# ----------------------------------------
main() {
  log "dotfiles dir: $DOTFILES_DIR"

  ensure_homebrew
  brew_bundle
  link_all

  log "Done."
  log "Please restart."
}

main "$@"
