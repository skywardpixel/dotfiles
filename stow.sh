#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}"

PACKAGES=(
  bin
  emacs
  eza
  ghostty
  git
  helix
  nvim
  ssh
  tmux
  vim
  zsh
)

ACTION="stow"
DRY_RUN=false
FORCE=false
RUN_DEPS=false
RUN_UPDATE=false
SELECTED_PKGS=()

show_help() {
  cat <<HELP
Usage: ./stow.sh [OPTIONS] [PACKAGES...]

Manage modular dotfiles using GNU Stow.

Options:
  --all          Stow all packages
  --deps         Install external dependencies for selected packages (after stowing)
  --update       Update external dependencies for selected packages
  --deps-only    Install dependencies only (do not stow)
  --update-only  Update dependencies only (do not stow)
  -f, --force    Force / adopt: Replace existing regular files with symlinks (backs up existing files)
  -R, --restow   Restow packages (prune dead links and relink)
  -D, --delete   Unstow / remove symlinks
  -n, --dry-run  Dry-run (show what would be done without doing it)
  -t, --target   Target directory (default: $HOME)
  -h, --help     Show this help message

Examples:
  ./stow.sh                       # Stow all packages
  ./stow.sh --all --deps          # Stow all packages and install dependencies
  ./stow.sh --deps-only vim tmux  # Install dependencies for vim and tmux only
  ./stow.sh --update-only         # Update dependencies for all packages
  ./stow.sh nvim zsh tmux         # Stow specific packages
  ./stow.sh -R                    # Restow all packages
  ./stow.sh -D                    # Unstow all packages
  ./stow.sh -n                    # Dry-run
HELP
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      SELECTED_PKGS+=("${PACKAGES[@]}")
      shift
      ;;
    --deps)
      RUN_DEPS=true
      shift
      ;;
    --update)
      RUN_UPDATE=true
      shift
      ;;
    --deps-only)
      ACTION="deps-only"
      RUN_DEPS=true
      shift
      ;;
    --update-only)
      ACTION="update-only"
      RUN_UPDATE=true
      shift
      ;;
    -f|--force|--adopt)
      FORCE=true
      shift
      ;;
    -R|--restow)
      ACTION="restow"
      shift
      ;;
    -D|--delete|--unstow)
      ACTION="delete"
      shift
      ;;
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -t|--target)
      TARGET_DIR="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      show_help
      exit 1
      ;;
    *)
      SELECTED_PKGS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#SELECTED_PKGS[@]} -eq 0 ]]; then
  SELECTED_PKGS+=("${PACKAGES[@]}")
fi

# Remove duplicates while preserving order
UNIQUE_PKGS=()
for pkg in "${SELECTED_PKGS[@]}"; do
  if [[ ! " ${UNIQUE_PKGS[*]:-} " =~ " ${pkg} " ]]; then
    UNIQUE_PKGS+=("$pkg")
  fi
done

mkdir -p \
  "${TARGET_DIR}/.config" \
  "${TARGET_DIR}/.local/bin" \
  "${TARGET_DIR}/.ssh/conf.d"

if [[ "${ACTION}" != "deps-only" && "${ACTION}" != "update-only" ]]; then
  if command -v stow >/dev/null 2>&1; then
    STOW_FLAGS=("-v" "-d" "${DOTFILES_DIR}" "-t" "${TARGET_DIR}")
    if [[ "$DRY_RUN" == true ]]; then
      STOW_FLAGS+=("-n")
    fi
    if [[ "$FORCE" == true ]]; then
      STOW_FLAGS+=("--adopt")
    fi

    case "${ACTION}" in
      restow) STOW_FLAGS+=("-R") ;;
      delete) STOW_FLAGS+=("-D") ;;
    esac

    echo "Using system GNU Stow..."
    stow "${STOW_FLAGS[@]}" "${UNIQUE_PKGS[@]}"
    echo "Done!"
  else
    # Native fallback using Python
    echo "GNU Stow not found in PATH; running native symlink manager..."
    DOTFILES_DIR="${DOTFILES_DIR}" \
    TARGET_DIR="${TARGET_DIR}" \
    ACTION="${ACTION}" \
    DRY_RUN="${DRY_RUN}" \
    FORCE="${FORCE}" \
    PKGS="${UNIQUE_PKGS[*]}" \
    python3 - << 'PYEOF'
import os
import sys
import shutil
from datetime import datetime
from pathlib import Path

dotfiles_dir = Path(os.environ["DOTFILES_DIR"])
target_dir = Path(os.environ["TARGET_DIR"])
action = os.environ["ACTION"]
dry_run = os.environ["DRY_RUN"] == "true"
force = os.environ["FORCE"] == "true"
pkgs = os.environ["PKGS"].split()

backup_dir = None
if force and not dry_run:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_dir = target_dir / f".dotfiles_backup_{timestamp}"

for pkg in pkgs:
    pkg_dir = dotfiles_dir / pkg
    if not pkg_dir.exists() or not pkg_dir.is_dir():
        print(f"Warning: Package '{pkg}' does not exist, skipping.")
        continue

    print(f"[{action.upper()}] Package: {pkg}")
    for root, dirs, files in os.walk(pkg_dir):
        for f in files:
            src_file = Path(root) / f
            rel_path = src_file.relative_to(pkg_dir)
            dest_file = target_dir / rel_path

            if action in ("delete", "restow"):
                if dest_file.is_symlink():
                    link_target = os.readlink(dest_file)
                    if str(src_file) == link_target or str(src_file.resolve()) == str(Path(link_target).resolve()):
                        if dry_run:
                            print(f"  [DRY-RUN] Would remove symlink: {dest_file}")
                        else:
                            dest_file.unlink()
                            print(f"  Removed symlink: {dest_file}")

            if action in ("stow", "restow"):
                dest_file.parent.mkdir(parents=True, exist_ok=True)
                if dest_file.is_symlink():
                    if dest_file.resolve() == src_file.resolve():
                        continue
                    if not dry_run:
                        dest_file.unlink()
                elif dest_file.exists():
                    if force:
                        if dry_run:
                            print(f"  [DRY-RUN] Would backup and replace regular file: {dest_file} -> {src_file}")
                        else:
                            backup_file = backup_dir / rel_path
                            backup_file.parent.mkdir(parents=True, exist_ok=True)
                            shutil.copy2(dest_file, backup_file)
                            dest_file.unlink()
                            dest_file.symlink_to(src_file)
                            print(f"  Backed up & linked: {dest_file} -> {src_file}")
                    else:
                        print(f"  [WARNING] Target already exists as a regular file: {dest_file} (use -f to replace)")
                        continue

                if dry_run:
                    print(f"  [DRY-RUN] Would link: {dest_file} -> {src_file}")
                else:
                    dest_file.symlink_to(src_file)
                    print(f"  Linked: {dest_file} -> {src_file}")

if backup_dir and backup_dir.exists():
    print(f"\nOriginal files backed up to: {backup_dir}")

print("Completed successfully!")
PYEOF
  fi
fi

# Run dependencies installation if requested
if [[ "$RUN_DEPS" == true && "$DRY_RUN" == false ]]; then
  echo ""
  echo "Installing external dependencies for selected packages..."
  for pkg in "${UNIQUE_PKGS[@]}"; do
    "${DOTFILES_DIR}/scripts/deps.sh" "$pkg" install
  done
fi

# Run dependencies update if requested
if [[ "$RUN_UPDATE" == true && "$DRY_RUN" == false ]]; then
  echo ""
  echo "Updating external dependencies for selected packages..."
  for pkg in "${UNIQUE_PKGS[@]}"; do
    "${DOTFILES_DIR}/scripts/deps.sh" "$pkg" update
  done
fi
