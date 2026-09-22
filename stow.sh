#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}"

CORE_PKGS=(
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

# Work packages live in a data file rather than inline, so this script can be
# published verbatim without carrying internal package names. The file is not
# copied into public releases, leaving GOOGLE_PKGS empty there.
GOOGLE_PKGS=()
if [[ -f "${DOTFILES_DIR}/packages.google" ]]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [[ -n "$line" ]] && GOOGLE_PKGS+=("$line")
  done < "${DOTFILES_DIR}/packages.google"
fi

ACTION="stow"
DRY_RUN=false
FORCE=false
RUN_DEPS=false
RUN_UPDATE=false
SELECTED_PKGS=()
# Distinguishes "user asked for nothing" from "user asked, nothing matched".
SELECTOR_GIVEN=false

show_help() {
  cat <<HELP
Usage: ./stow.sh [OPTIONS] [PACKAGES...]

Manage dotfiles using GNU Stow (with automatic fallback if stow binary is not installed).

Options:
  --core         Stow core / personal packages
  --google       Stow Google / work packages
  --all          Stow all packages (core + google)
  --deps         Install external dependencies for selected packages (after stowing)
  --update       Update external dependencies for selected packages
  --deps-only    Install dependencies only (do not stow)
  --update-only  Update dependencies only (do not stow)
  -f, --force    Force / adopt: Replace existing regular files with symlinks (backs up existing files)
  -R, --restow   Restow packages (prune dead links and relink)
  -D, --delete   Unstow / remove symlinks
  -s, --status   Report drift: de-linked symlinks and out-of-sync copy-mode files
      --sync     Copy-mode files only: pull app-written changes from \$HOME back into the repo
  -l, --list     List available packages
  -n, --dry-run  Dry-run (show what would be done without doing it)
  -t, --target   Target directory (default: $HOME)
  -h, --help     Show this help message

Copy mode (.stow-copy):
  Most files are deployed as symlinks. Some applications rewrite their own config
  with a temp file + rename(2), which destroys a symlink and silently orphans the
  repo copy. For those files, create a '.stow-copy' manifest in the package listing
  one glob per line (matched against the package-relative path). Listed files are
  deployed as regular copies instead, and a hash of what was deployed is recorded
  under .stow-state/ so drift can be detected:

      ./stow.sh -s --all     # what has drifted?
      ./stow.sh --sync       # pull app-written changes back into the repo

  Prefer relocating the app's config into the checkout (e.g. an env var pointing at
  the repo) where the app supports it -- that needs no sync step at all. Copy mode
  is the fallback for apps that offer no such escape hatch.

Examples:
  ./stow.sh --core                # Stow core packages
  ./stow.sh --all                 # Stow everything
  ./stow.sh --all --deps          # Stow all packages and install dependencies
  ./stow.sh --deps-only vim tmux  # Install dependencies for vim and tmux only
  ./stow.sh --update-only         # Update dependencies for core packages
  ./stow.sh -f --all              # Force apply / replace existing regular files with symlinks
  ./stow.sh -R --all              # Restow everything
  ./stow.sh -D tmux               # Unstow specific package
  ./stow.sh -n --core             # Dry-run core packages
  ./stow.sh -s --all              # Audit for drift (exits non-zero if anything drifted)
HELP
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --core)
      SELECTOR_GIVEN=true
      SELECTED_PKGS+=("${CORE_PKGS[@]}")
      shift
      ;;
    --google)
      SELECTOR_GIVEN=true
      # Expansion is guarded: GOOGLE_PKGS is empty in a public checkout and
      # "${arr[@]}" on an empty array trips set -u in older bash.
      SELECTED_PKGS+=(${GOOGLE_PKGS[@]+"${GOOGLE_PKGS[@]}"})
      shift
      ;;
    --all)
      SELECTOR_GIVEN=true
      SELECTED_PKGS+=("${CORE_PKGS[@]}" ${GOOGLE_PKGS[@]+"${GOOGLE_PKGS[@]}"})
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
    -s|--status|--check)
      ACTION="status"
      shift
      ;;
    -l|--list)
      echo "Core Packages:   ${CORE_PKGS[*]}"
      if (( ${#GOOGLE_PKGS[@]} )); then
        echo "Google Packages: ${GOOGLE_PKGS[*]}"
      fi
      exit 0
      ;;
    --sync)
      ACTION="sync"
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
      SELECTOR_GIVEN=true
      SELECTED_PKGS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#SELECTED_PKGS[@]} -eq 0 ]]; then
  if [[ "${SELECTOR_GIVEN}" == true ]]; then
    # A selector was given but matched nothing -- e.g. --google in a public
    # checkout, which has no work packages. Silently falling back to --core
    # here would stow something the user did not ask for.
    echo "No packages matched the given selection; nothing to do."
    exit 0
  fi
  echo "No packages specified. Defaulting to --core."
  SELECTED_PKGS+=("${CORE_PKGS[@]}")
fi

# Remove duplicates while preserving order
UNIQUE_PKGS=()
for pkg in "${SELECTED_PKGS[@]}"; do
  if [[ ! " ${UNIQUE_PKGS[*]:-} " =~ " ${pkg} " ]]; then
    UNIQUE_PKGS+=("$pkg")
  fi
done

# Ensure the common target directories exist. Package-specific directories are
# created on demand as each file is deployed, so nothing package-specific needs
# to be listed here.
mkdir -p \
  "${TARGET_DIR}/.config" \
  "${TARGET_DIR}/.local/bin" \
  "${TARGET_DIR}/.ssh/conf.d"

if [[ "${ACTION}" != "deps-only" && "${ACTION}" != "update-only" ]]; then
  # Decide between system GNU Stow and the native implementation.
  #
  # GNU Stow is symlink-only and has no notion of content drift, so it cannot
  # service copy-mode files, 'status' or 'sync'. Silently letting it symlink a
  # file the package explicitly marked copy-mode would reintroduce exactly the
  # write-back bug copy mode exists to prevent, so prefer the native path
  # whenever copy mode is involved.
  USE_NATIVE=true
  if command -v stow >/dev/null 2>&1; then
    USE_NATIVE=false
    if [[ "${ACTION}" == "status" || "${ACTION}" == "sync" ]]; then
      USE_NATIVE=true
    else
      for pkg in "${UNIQUE_PKGS[@]}"; do
        if [[ -f "${DOTFILES_DIR}/${pkg}/.stow-copy" ]]; then
          echo "Note: package '${pkg}' declares copy-mode files; using the native"
          echo "      implementation instead of GNU Stow (which is symlink-only)."
          USE_NATIVE=true
          break
        fi
      done
    fi
  fi

  if [[ "${USE_NATIVE}" == false ]]; then
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
    # Native implementation
    if [[ "${ACTION}" != "status" && "${ACTION}" != "sync" ]]; then
      echo "Running native symlink manager..."
    fi
    NATIVE_RC=0
    set +e
    DOTFILES_DIR="${DOTFILES_DIR}" \
    TARGET_DIR="${TARGET_DIR}" \
    ACTION="${ACTION}" \
    DRY_RUN="${DRY_RUN}" \
    FORCE="${FORCE}" \
    PKGS="${UNIQUE_PKGS[*]}" \
    python3 - << 'PYEOF'
import fnmatch
import hashlib
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

# ---------------------------------------------------------------- copy mode --
#
# Files listed in a package's .stow-copy manifest are deployed as regular
# copies instead of symlinks, for applications that rewrite their own config
# with a temp file + rename(2) (which replaces the path, destroying a symlink).
#
# The cost of copying is that the repo and the deployed file can now diverge.
# A plain two-way diff between them cannot tell a repo edit from an app write,
# so we record the hash of what was last deployed and use it as the referee:
#
#     repo==rec  live==rec   meaning        action
#     yes        yes         clean          -
#     no         yes         repo edited    stow (apply)
#     yes        no          app wrote it   sync (pull back)
#     no         no          both changed   refuse, let a human decide
#
# The last row is the one that silently eats data in most tools. We refuse.

MANIFEST = ".stow-copy"

# State is per *target*, not just per package: deploying the same package to a
# different --target (a test sandbox, a second account) must not overwrite the
# baseline recorded for $HOME, or a later 'status' would compare against the
# wrong deployment and either miss a real app write or invent a phantom one.
_target_key = hashlib.sha256(
    str(target_dir.resolve()).encode()).hexdigest()[:12]
STATE_DIR = dotfiles_dir / ".stow-state" / _target_key

exit_code = 0


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def load_patterns(pkg_dir):
    """Read a package's .stow-copy globs (one per line, '#' comments)."""
    manifest = pkg_dir / MANIFEST
    if not manifest.is_file():
        return []
    patterns = []
    for line in manifest.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            patterns.append(line)
    return patterns


def is_copy(rel_posix, patterns):
    # Matched against the package-relative path, so '*' spans directories.
    return any(fnmatch.fnmatch(rel_posix, p) for p in patterns)


def state_path(pkg, rel_posix):
    return STATE_DIR / pkg / (rel_posix + ".sha256")


def read_state(pkg, rel_posix):
    p = state_path(pkg, rel_posix)
    return p.read_text().strip() if p.is_file() else None


def write_state(pkg, rel_posix, digest):
    p = state_path(pkg, rel_posix)
    p.parent.mkdir(parents=True, exist_ok=True)
    # Breadcrumb so the hashed directory name above can be identified by hand.
    marker = STATE_DIR / ".target"
    if not marker.exists():
        marker.write_text(str(target_dir.resolve()) + "\n")
    p.write_text(digest + "\n")


def clear_state(pkg, rel_posix):
    p = state_path(pkg, rel_posix)
    if p.is_file():
        p.unlink()


def classify(pkg, rel_posix, src_file, dest_file):
    """Compare repo / deployed / recorded. See the table above."""
    if not dest_file.exists() and not dest_file.is_symlink():
        return "missing"
    recorded = read_state(pkg, rel_posix)
    live = sha256(dest_file)
    repo = sha256(src_file)
    if recorded is None:
        # Never deployed by us: safe only if it already matches the repo.
        return "adopted" if live == repo else "untracked"
    if repo == recorded and live == recorded:
        return "clean"
    if repo != recorded and live == recorded:
        return "repo"
    if repo == recorded and live != recorded:
        return "live"
    # Both moved. If they happen to agree, there is nothing to resolve.
    return "converged" if live == repo else "both"


backup_dir = None
if force and not dry_run:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_dir = target_dir / f".dotfiles_backup_{timestamp}"


def backup(dest_file, rel_path):
    if backup_dir is None:
        return
    backup_file = backup_dir / rel_path
    backup_file.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(dest_file, backup_file)


def deploy_copy(pkg, rel_path, src_file, dest_file):
    """Deploy one copy-mode file, refusing to destroy an unsynced app write."""
    global exit_code
    rel_posix = rel_path.as_posix()
    state = classify(pkg, rel_posix, src_file, dest_file)

    if state == "clean":
        print(f"  Already current (copy): {dest_file}")
        return
    if state == "converged":
        if not dry_run:
            write_state(pkg, rel_posix, sha256(src_file))
        print(f"  Already current (copy, state refreshed): {dest_file}")
        return
    if state in ("live", "both", "untracked") and not force:
        why = {
            "live": "target changed since deploy (the app wrote it); "
                    "run './stow.sh --sync' to keep it",
            "both": "BOTH the repo and the target changed since deploy; "
                    "resolve by hand",
            "untracked": "target exists but was not deployed by stow.sh",
        }[state]
        print(f"  [WARNING] Skipped (copy): {dest_file}")
        print(f"            {why}")
        print(f"            (use -f to overwrite; the target is backed up first)")
        exit_code = 1
        return

    if dry_run:
        print(f"  [DRY-RUN] Would copy: {src_file} -> {dest_file}")
        return

    if dest_file.is_symlink():
        dest_file.unlink()
    elif dest_file.exists():
        if force:
            backup(dest_file, rel_path)
        dest_file.unlink()
    shutil.copy2(src_file, dest_file)
    write_state(pkg, rel_posix, sha256(src_file))
    print(f"  Copied: {src_file} -> {dest_file}")


def delete_copy(pkg, rel_path, src_file, dest_file):
    """Remove a deployed copy, but never one holding unsynced changes."""
    global exit_code
    rel_posix = rel_path.as_posix()
    if not dest_file.exists() and not dest_file.is_symlink():
        if not dry_run:
            clear_state(pkg, rel_posix)
        return

    recorded = read_state(pkg, rel_posix)
    live = sha256(dest_file)
    reference = recorded if recorded is not None else sha256(src_file)
    if live != reference:
        # Mirrors the symlink branch, which only removes links it owns.
        print(f"  [WARNING] Kept (copy): {dest_file}")
        print(f"            target has unsynced changes; './stow.sh --sync' to save them")
        exit_code = 1
        return

    if dry_run:
        print(f"  [DRY-RUN] Would remove copy: {dest_file}")
        return
    dest_file.unlink()
    clear_state(pkg, rel_posix)
    print(f"  Removed copy: {dest_file}")


def sync_copy(pkg, rel_path, src_file, dest_file):
    """Pull an app-written change from the target back into the repo."""
    global exit_code
    rel_posix = rel_path.as_posix()
    state = classify(pkg, rel_posix, src_file, dest_file)

    if state in ("clean", "missing"):
        return
    if state == "repo":
        print(f"  Repo is ahead (run ./stow.sh to apply): {dest_file}")
        return
    if state == "both":
        print(f"  [WARNING] Not synced: {dest_file}")
        print(f"            BOTH the repo and the target changed since deploy.")
        print(f"            Diff them and resolve by hand -- syncing would discard")
        print(f"            your repo edit, applying would discard the app's write.")
        exit_code = 1
        return

    # live / untracked / converged: the target is authoritative.
    if dry_run:
        print(f"  [DRY-RUN] Would sync: {dest_file} -> {src_file}")
        return
    shutil.copy2(dest_file, src_file)
    write_state(pkg, rel_posix, sha256(src_file))
    print(f"  Synced: {dest_file} -> {src_file}")

findings = []  # (severity, package, message) -- collected for 'status'

for pkg in pkgs:
    pkg_dir = dotfiles_dir / pkg
    if not pkg_dir.exists() or not pkg_dir.is_dir():
        print(f"Warning: Package '{pkg}' does not exist, skipping.")
        continue

    patterns = load_patterns(pkg_dir)

    if action not in ("status", "sync"):
        print(f"[{action.upper()}] Package: {pkg}")

    for root, dirs, files in os.walk(pkg_dir):
        for f in sorted(files):
            src_file = Path(root) / f
            rel_path = src_file.relative_to(pkg_dir)
            rel_posix = rel_path.as_posix()

            # The manifest configures the package; it is not deployed.
            if rel_posix == MANIFEST:
                continue

            dest_file = target_dir / rel_path
            copy_mode = is_copy(rel_posix, patterns)

            if action == "status":
                if copy_mode:
                    state = classify(pkg, rel_posix, src_file, dest_file)
                    note = {
                        "clean": None,
                        "adopted": None,
                        "missing": (0, "not deployed"),
                        "repo": (0, "repo edited -- ./stow.sh to apply"),
                        "converged": (0, "repo and target agree; state stale"),
                        "live": (1, "APP WROTE TARGET -- ./stow.sh --sync to keep it"),
                        "both": (1, "BOTH changed -- resolve by hand"),
                        "untracked": (1, "target exists, not deployed by stow.sh"),
                    }[state]
                    if note:
                        findings.append((note[0], pkg, f"copy   {rel_posix}: {note[1]}"))
                else:
                    if dest_file.is_symlink():
                        if os.path.realpath(dest_file) != str(src_file.resolve()):
                            findings.append(
                                (1, pkg, f"link   {rel_posix}: symlink points elsewhere "
                                         f"({os.readlink(dest_file)})"))
                    elif dest_file.exists():
                        same = dest_file.read_bytes() == src_file.read_bytes()
                        findings.append(
                            (1, pkg, f"link   {rel_posix}: DE-LINKED (regular file, "
                                     f"{'identical to' if same else 'DIFFERS from'} repo)"))
                    else:
                        findings.append((0, pkg, f"link   {rel_posix}: not deployed"))
                continue

            if action == "sync":
                if copy_mode:
                    sync_copy(pkg, rel_path, src_file, dest_file)
                continue

            if action in ("delete", "restow"):
                if copy_mode:
                    # Only tear down on an explicit delete; for restow, deploy_copy
                    # replaces the file in place and keeps the drift guards.
                    if action == "delete":
                        delete_copy(pkg, rel_path, src_file, dest_file)
                elif dest_file.is_symlink():
                    link_target = os.readlink(dest_file)
                    if str(src_file) == link_target or str(src_file.resolve()) == str(Path(link_target).resolve()):
                        if dry_run:
                            print(f"  [DRY-RUN] Would remove symlink: {dest_file}")
                        else:
                            dest_file.unlink()
                            print(f"  Removed symlink: {dest_file}")

            if action in ("stow", "restow"):
                dest_file.parent.mkdir(parents=True, exist_ok=True)
                if copy_mode:
                    deploy_copy(pkg, rel_path, src_file, dest_file)
                elif dest_file.is_symlink():
                    if dest_file.resolve() == src_file.resolve():
                        print(f"  Already linked: {dest_file} -> {src_file}")
                        continue
                    if dry_run:
                        print(f"  [DRY-RUN] Would replace symlink: {dest_file} -> {src_file}")
                    else:
                        dest_file.unlink()
                        dest_file.symlink_to(src_file)
                        print(f"  Updated symlink: {dest_file} -> {src_file}")
                elif dest_file.exists():
                    if force:
                        if dry_run:
                            print(f"  [DRY-RUN] Would backup and replace regular file: {dest_file} -> {src_file}")
                        else:
                            # Backup original file
                            backup_file = backup_dir / rel_path
                            backup_file.parent.mkdir(parents=True, exist_ok=True)
                            shutil.copy2(dest_file, backup_file)
                            dest_file.unlink()
                            dest_file.symlink_to(src_file)
                            print(f"  Backed up & linked: {dest_file} -> {src_file}")
                    else:
                        print(f"  [WARNING] Target already exists as a regular file: {dest_file} (use -f to replace)")
                        continue
                else:
                    if dry_run:
                        print(f"  [DRY-RUN] Would link: {dest_file} -> {src_file}")
                    else:
                        dest_file.symlink_to(src_file)
                        print(f"  Linked: {dest_file} -> {src_file}")

if action == "status":
    problems = [x for x in findings if x[0] == 1]
    notes = [x for x in findings if x[0] == 0]
    for severity, pkg, msg in problems:
        print(f"  [DRIFT] {pkg}: {msg}")
    for severity, pkg, msg in notes:
        print(f"  [note]  {pkg}: {msg}")
    if problems:
        print(f"\n{len(problems)} file(s) need attention, {len(notes)} note(s).")
        exit_code = 1
    else:
        print(f"Clean: no drift across {len(pkgs)} package(s)"
              + (f", {len(notes)} note(s)." if notes else "."))
    sys.exit(exit_code)

if backup_dir and backup_dir.exists():
    print(f"\nOriginal files backed up to: {backup_dir}")

if exit_code:
    print("\nCompleted with warnings.")
else:
    print("Completed successfully!")
sys.exit(exit_code)
PYEOF
    NATIVE_RC=$?
    set -e
    # 'status' is a query: its exit code is the answer, so report it now.
    # For the mutating actions a non-zero code means "some files were skipped";
    # remember it for the final exit but keep going so --deps still runs.
    if [[ "${ACTION}" == "status" ]]; then
      exit "${NATIVE_RC}"
    fi
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

# Surface "some files were skipped" to callers and CI.
exit "${NATIVE_RC:-0}"
