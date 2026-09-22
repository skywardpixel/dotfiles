#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-install}"
VIM_AUTOLOAD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vim/autoload"
PLUG_VIM="${VIM_AUTOLOAD_DIR}/plug.vim"
PLUG_URL="https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"

case "$ACTION" in
  install)
    # Clean up broken symlink if left over from previous stow
    if [[ -L "$PLUG_VIM" && ! -e "$PLUG_VIM" ]]; then
      rm -f "$PLUG_VIM"
    fi
    if [[ ! -f "$PLUG_VIM" ]]; then
      echo "Downloading vim-plug into ${PLUG_VIM}..."
      mkdir -p "$VIM_AUTOLOAD_DIR"
      curl -fLo "$PLUG_VIM" --create-dirs "$PLUG_URL"
    else
      echo "vim-plug already installed at ${PLUG_VIM}."
    fi
    if command -v vim >/dev/null 2>&1; then
      echo "Installing Vim plugins via vim-plug..."
      vim -es -u "${XDG_CONFIG_HOME:-$HOME/.config}/vim/vimrc" -i NONE -c "PlugInstall" -c "qa" || true
    fi
    ;;
  update)
    # Clean up broken symlink if left over
    if [[ -L "$PLUG_VIM" && ! -e "$PLUG_VIM" ]]; then
      rm -f "$PLUG_VIM"
    fi
    echo "Updating vim-plug..."
    mkdir -p "$VIM_AUTOLOAD_DIR"
    curl -fLo "$PLUG_VIM" --create-dirs "$PLUG_URL"
    if command -v vim >/dev/null 2>&1; then
      echo "Updating Vim plugins via vim-plug..."
      vim -es -u "${XDG_CONFIG_HOME:-$HOME/.config}/vim/vimrc" -i NONE -c "PlugUpdate" -c "qa" || true
    fi
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
