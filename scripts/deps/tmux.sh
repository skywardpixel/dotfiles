#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-install}"
TPM_DIR="${HOME}/.tmux/plugins/tpm"

case "$ACTION" in
  install)
    if [[ ! -d "$TPM_DIR" ]]; then
      echo "Cloning TPM (Tmux Plugin Manager) into ${TPM_DIR}..."
      git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
    else
      echo "TPM already installed at ${TPM_DIR}."
    fi
    if [[ -x "${TPM_DIR}/bin/install_plugins" ]] && command -v tmux >/dev/null 2>&1; then
      echo "Installing Tmux plugins..."
      "${TPM_DIR}/bin/install_plugins" || true
    fi
    ;;
  update)
    if [[ -d "$TPM_DIR/.git" ]]; then
      echo "Updating TPM..."
      git -C "$TPM_DIR" pull --ff-only || true
    fi
    if [[ -x "${TPM_DIR}/bin/update_plugins" ]] && command -v tmux >/dev/null 2>&1; then
      echo "Updating Tmux plugins..."
      "${TPM_DIR}/bin/update_plugins" all || true
    fi
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
