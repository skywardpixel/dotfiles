#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-install}"
SHADERS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/shaders"

case "$ACTION" in
  install)
    if [[ ! -d "$SHADERS_DIR" ]]; then
      echo "Cloning Ghostty shaders into ${SHADERS_DIR}..."
      mkdir -p "$(dirname "$SHADERS_DIR")"
      git clone --depth=1 https://github.com/hackr-sh/ghostty-shaders "$SHADERS_DIR"
    else
      echo "Ghostty shaders already installed at ${SHADERS_DIR}."
    fi
    ;;
  update)
    if [[ -d "$SHADERS_DIR/.git" ]]; then
      echo "Updating Ghostty shaders..."
      git -C "$SHADERS_DIR" pull --ff-only || true
    fi
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
