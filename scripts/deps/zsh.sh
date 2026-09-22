#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-install}"
ANTIDOTE_DIR="${HOME}/.antidote"

case "$ACTION" in
  install)
    if [[ ! -d "$ANTIDOTE_DIR" ]]; then
      echo "Cloning Antidote into ${ANTIDOTE_DIR}..."
      git clone --depth=1 https://github.com/mattmc3/antidote "$ANTIDOTE_DIR"
    else
      echo "Antidote already installed at ${ANTIDOTE_DIR}."
    fi
    if command -v zsh >/dev/null 2>&1 && [[ -f "$ANTIDOTE_DIR/antidote.zsh" ]]; then
      echo "Loading Zsh plugins via Antidote..."
      zsh -c "source ${ANTIDOTE_DIR}/antidote.zsh && antidote load" || true
    fi
    ;;
  update)
    if [[ -d "$ANTIDOTE_DIR/.git" ]]; then
      echo "Updating Antidote..."
      git -C "$ANTIDOTE_DIR" pull --ff-only || true
    fi
    if command -v zsh >/dev/null 2>&1 && [[ -f "$ANTIDOTE_DIR/antidote.zsh" ]]; then
      echo "Updating Zsh plugins via Antidote..."
      zsh -c "source ${ANTIDOTE_DIR}/antidote.zsh && antidote update" || true
    fi
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
