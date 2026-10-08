#!/usr/bin/env bash
# Install or update one package's external dependencies.
#
# zsh, tmux and vim also bootstrap themselves on first start; `install` here
# only fetches everything ahead of time. Packages not listed have no deps.
#
# Usage: ./scripts/deps.sh <package> [install|update]
set -euo pipefail

PKG="${1:?usage: $0 <package> [install|update]}"
ACTION="${2:-install}"
case "$ACTION" in
  install | update) ;;
  *) echo "Unknown action: $ACTION" >&2; exit 1 ;;
esac
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

# git_dep DIR URL -- clone if missing; fast-forward on update.
git_dep() {
  if [[ ! -d "$1" ]]; then
    echo "Cloning $2 into $1..."
    mkdir -p "$(dirname "$1")"
    git clone --depth=1 "$2" "$1"
  elif [[ "$ACTION" == update && -d "$1/.git" ]]; then
    echo "Updating $1..."
    git -C "$1" pull --ff-only || true
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

case "$PKG" in
  ghostty)
    git_dep "$CONFIG/ghostty/shaders" https://github.com/hackr-sh/ghostty-shaders
    ;;
  tmux)
    tpm="$HOME/.tmux/plugins/tpm"
    git_dep "$tpm" https://github.com/tmux-plugins/tpm
    if have tmux; then
      if [[ "$ACTION" == install ]]; then
        "$tpm/bin/install_plugins" || true
      else
        "$tpm/bin/update_plugins" all || true
      fi
    fi
    ;;
  vim)
    plug="$CONFIG/vim/autoload/plug.vim"
    if [[ ! -f "$plug" || "$ACTION" == update ]]; then
      echo "Downloading vim-plug into $plug..."
      curl -fLo "$plug" --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    fi
    if have vim; then
      cmd=PlugInstall
      [[ "$ACTION" == update ]] && cmd=PlugUpdate
      vim -es -u "$CONFIG/vim/vimrc" -i NONE -c "$cmd" -c qa || true
    fi
    ;;
  zsh)
    antidote="$HOME/.antidote"
    git_dep "$antidote" https://github.com/mattmc3/antidote
    if have zsh; then
      cmd=load
      [[ "$ACTION" == update ]] && cmd=update
      zsh -c "source $antidote/antidote.zsh && antidote $cmd" || true
    fi
    ;;
esac
