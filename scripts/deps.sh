#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODULE="${1:-}"
ACTION="${2:-install}" # install | update

if [[ -z "$MODULE" ]]; then
  echo "Usage: $0 <module> [install|update]" >&2
  exit 1
fi

MODULE_SCRIPT="${SCRIPT_DIR}/deps/${MODULE}.sh"

if [[ -f "$MODULE_SCRIPT" ]]; then
  echo "==> [$ACTION] Dependencies for ${MODULE}..."
  bash "$MODULE_SCRIPT" "$ACTION"
else
  # No external dependencies defined for this module; cleanly skip
  exit 0
fi
