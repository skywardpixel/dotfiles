#!/usr/bin/env python3
"""Manage dotfiles using GNU Stow (with native fallback and copy-mode support)."""

from datetime import datetime
import fnmatch
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys

DOTFILES_DIR = Path(__file__).resolve().parent

CORE_PKGS = [
    "bin",
    "emacs",
    "eza",
    "ghostty",
    "git",
    "helix",
    "nvim",
    "ssh",
    "tmux",
    "vim",
    "zsh",
]

# Work packages live in a data file rather than inline, so this script can be
# published verbatim without carrying internal package names. The file is not
# present in public releases, leaving GOOGLE_PKGS empty there.
GOOGLE_PKGS: list[str] = []
_google_pkg_file = DOTFILES_DIR / "packages.google"
if _google_pkg_file.is_file():
    for _raw in _google_pkg_file.read_text(encoding="utf-8").splitlines():
        _item = "".join(_raw.split("#", 1)[0].split())
        if _item:
            GOOGLE_PKGS.append(_item)

MANIFEST = ".stow-copy"


def show_help(target_dir: Path) -> None:
    print(f"""Usage: ./stow.py [OPTIONS] [PACKAGES...]

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
      --sync     Copy-mode files only: pull app-written changes from $HOME back into the repo
  -l, --list     List available packages
      --list-packages [core|google|all]
                 Same list, machine-readable: bare names, one per line
  -n, --dry-run  Dry-run (show what would be done without doing it)
  -t, --target   Target directory (default: {target_dir})
  -h, --help     Show this help message

Copy mode (.stow-copy):
  Most files are deployed as symlinks. Some applications rewrite their own config
  with a temp file + rename(2), which destroys a symlink and silently orphans the
  repo copy. For those files, create a '.stow-copy' manifest in the package listing
  one glob per line (matched against the package-relative path). Listed files are
  deployed as regular copies instead, and a hash of what was deployed is recorded
  under .stow-state/ so drift can be detected:

      ./stow.py -s --all     # what has drifted?
      ./stow.py --sync       # pull app-written changes back into the repo

  Prefer relocating the app's config into the checkout (e.g. an env var pointing at
  the repo) where the app supports it -- that needs no sync step at all. Copy mode
  is the fallback for apps that offer no such escape hatch.

Examples:
  ./stow.py --core                # Stow core packages
  ./stow.py --all                 # Stow everything
  ./stow.py --all --deps          # Stow all packages and install dependencies
  ./stow.py --deps-only vim tmux  # Install dependencies for vim and tmux only
  ./stow.py --update-only         # Update dependencies for core packages
  ./stow.py -f --all              # Force apply / replace existing regular files with symlinks
  ./stow.py -R --all              # Restow everything
  ./stow.py -D tmux               # Unstow specific package
  ./stow.py -n --core             # Dry-run core packages
  ./stow.py -s --all              # Audit for drift (exits non-zero if anything drifted)""")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def load_patterns(pkg_dir: Path) -> list[str]:
    """Read a package's .stow-copy globs (one per line, '#' comments)."""
    manifest = pkg_dir / MANIFEST
    if not manifest.is_file():
        return []
    patterns = []
    for line in manifest.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            patterns.append(line)
    return patterns


def is_copy(rel_posix: str, patterns: list[str]) -> bool:
    # Matched against the package-relative path, so '*' spans directories.
    return any(fnmatch.fnmatch(rel_posix, p) for p in patterns)


def via_folded_dir(dest_file: Path, src_file: Path) -> bool:
    """True if dest is reached through a symlinked parent directory into the repo.

    GNU Stow "folds" a directory owned by a single package into one symlink, so
    the files beneath it are not symlinks themselves -- they *are* the repo
    files. Treating them as regular files would report false drift, and with -f
    would delete the repo file and replace it with a symlink to itself.
    """
    return (
        not dest_file.is_symlink()
        and dest_file.exists()
        and os.path.realpath(dest_file) == os.path.realpath(src_file)
    )


def run_native_engine(
    dotfiles_dir: Path,
    target_dir: Path,
    action: str,
    dry_run: bool,
    force: bool,
    pkgs: list[str],
) -> int:
    # ------------------------------------------------------------ copy mode --
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

    # State is per *target*, not just per package: deploying the same package to a
    # different --target (a test sandbox, a second account) must not overwrite the
    # baseline recorded for $HOME, or a later 'status' would compare against the
    # wrong deployment and either miss a real app write or invent a phantom one.
    target_key = hashlib.sha256(str(target_dir.resolve()).encode()).hexdigest()[:12]
    state_dir = dotfiles_dir / ".stow-state" / target_key

    exit_code = 0

    def state_path(pkg: str, rel_posix: str) -> Path:
        return state_dir / pkg / (rel_posix + ".sha256")

    def read_state(pkg: str, rel_posix: str) -> str | None:
        p = state_path(pkg, rel_posix)
        return p.read_text(encoding="utf-8").strip() if p.is_file() else None

    def write_state(pkg: str, rel_posix: str, digest: str) -> None:
        p = state_path(pkg, rel_posix)
        p.parent.mkdir(parents=True, exist_ok=True)
        # Breadcrumb so the hashed directory name above can be identified by hand.
        marker = state_dir / ".target"
        if not marker.exists():
            marker.write_text(str(target_dir.resolve()) + "\n", encoding="utf-8")
        p.write_text(digest + "\n", encoding="utf-8")

    def clear_state(pkg: str, rel_posix: str) -> None:
        p = state_path(pkg, rel_posix)
        if p.is_file():
            p.unlink()

    def classify(pkg: str, rel_posix: str, src_file: Path, dest_file: Path) -> str:
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

    backup_dir: Path | None = None
    if force and not dry_run:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_dir = target_dir / f".dotfiles_backup_{timestamp}"

    def backup(dest_file: Path, rel_path: Path) -> None:
        if backup_dir is None:
            return
        backup_file = backup_dir / rel_path
        backup_file.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(dest_file, backup_file)

    def deploy_copy(pkg: str, rel_path: Path, src_file: Path, dest_file: Path) -> None:
        """Deploy one copy-mode file, refusing to destroy an unsynced app write."""
        nonlocal exit_code
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
                        "run './stow.py --sync' to keep it",
                "both": "BOTH the repo and the target changed since deploy; "
                        "resolve by hand",
                "untracked": "target exists but was not deployed by stow.py",
            }[state]
            print(f"  [WARNING] Skipped (copy): {dest_file}")
            print(f"            {why}")
            print("            (use -f to overwrite; the target is backed up first)")
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

    def delete_copy(pkg: str, rel_path: Path, src_file: Path, dest_file: Path) -> None:
        """Remove a deployed copy, but never one holding unsynced changes."""
        nonlocal exit_code
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
            print("            target has unsynced changes; './stow.py --sync' to save them")
            exit_code = 1
            return

        if dry_run:
            print(f"  [DRY-RUN] Would remove copy: {dest_file}")
            return
        dest_file.unlink()
        clear_state(pkg, rel_posix)
        print(f"  Removed copy: {dest_file}")

    def sync_copy(pkg: str, rel_path: Path, src_file: Path, dest_file: Path) -> None:
        """Pull an app-written change from the target back into the repo."""
        nonlocal exit_code
        rel_posix = rel_path.as_posix()
        state = classify(pkg, rel_posix, src_file, dest_file)

        if state in ("clean", "missing"):
            return
        if state == "repo":
            print(f"  Repo is ahead (run ./stow.py to apply): {dest_file}")
            return
        if state == "both":
            print(f"  [WARNING] Not synced: {dest_file}")
            print("            BOTH the repo and the target changed since deploy.")
            print("            Diff them and resolve by hand -- syncing would discard")
            print("            your repo edit, applying would discard the app's write.")
            exit_code = 1
            return

        # live / untracked / converged: the target is authoritative.
        if dry_run:
            print(f"  [DRY-RUN] Would sync: {dest_file} -> {src_file}")
            return
        shutil.copy2(dest_file, src_file)
        write_state(pkg, rel_posix, sha256(src_file))
        print(f"  Synced: {dest_file} -> {src_file}")

    findings: list[tuple[int, str, str]] = []

    for pkg in pkgs:
        pkg_dir = dotfiles_dir / pkg
        if not pkg_dir.exists() or not pkg_dir.is_dir():
            print(f"Warning: Package '{pkg}' does not exist, skipping.")
            continue

        patterns = load_patterns(pkg_dir)

        if action not in ("status", "sync"):
            print(f"[{action.upper()}] Package: {pkg}")

        for root, _dirs, files in os.walk(pkg_dir):
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
                            "repo": (0, "repo edited -- ./stow.py to apply"),
                            "converged": (0, "repo and target agree; state stale"),
                            "live": (1, "APP WROTE TARGET -- ./stow.py --sync to keep it"),
                            "both": (1, "BOTH changed -- resolve by hand"),
                            "untracked": (1, "target exists, not deployed by stow.py"),
                        }[state]
                        if note:
                            findings.append((note[0], pkg, f"copy   {rel_posix}: {note[1]}"))
                    else:
                        if via_folded_dir(dest_file, src_file):
                            pass
                        elif dest_file.is_symlink():
                            if os.path.realpath(dest_file) != str(src_file.resolve()):
                                findings.append(
                                    (
                                        1,
                                        pkg,
                                        f"link   {rel_posix}: symlink points elsewhere "
                                        f"({os.readlink(dest_file)})",
                                    )
                                )
                        elif dest_file.exists():
                            same = dest_file.read_bytes() == src_file.read_bytes()
                            findings.append(
                                (
                                    1,
                                    pkg,
                                    f"link   {rel_posix}: DE-LINKED (regular file, "
                                    f"{'identical to' if same else 'DIFFERS from'} repo)",
                                )
                            )
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
                        if str(src_file) == link_target or str(src_file.resolve()) == str(
                            Path(link_target).resolve()
                        ):
                            if dry_run:
                                print(f"  [DRY-RUN] Would remove symlink: {dest_file}")
                            else:
                                dest_file.unlink()
                                print(f"  Removed symlink: {dest_file}")

                if action in ("stow", "restow"):
                    dest_file.parent.mkdir(parents=True, exist_ok=True)
                    if via_folded_dir(dest_file, src_file):
                        print(f"  Already linked (folded directory): {dest_file}")
                    elif copy_mode:
                        deploy_copy(pkg, rel_path, src_file, dest_file)
                    elif dest_file.is_symlink():
                        if dest_file.resolve() == src_file.resolve():
                            print(f"  Already linked: {dest_file} -> {src_file}")
                            continue
                        if dry_run:
                            print(
                                f"  [DRY-RUN] Would replace symlink: {dest_file} -> {src_file}"
                            )
                        else:
                            dest_file.unlink()
                            dest_file.symlink_to(src_file)
                            print(f"  Updated symlink: {dest_file} -> {src_file}")
                    elif dest_file.exists():
                        if force:
                            if dry_run:
                                print(
                                    "  [DRY-RUN] Would backup and replace regular file: "
                                    f"{dest_file} -> {src_file}"
                                )
                            else:
                                assert backup_dir is not None
                                backup_file = backup_dir / rel_path
                                backup_file.parent.mkdir(parents=True, exist_ok=True)
                                shutil.copy2(dest_file, backup_file)
                                dest_file.unlink()
                                dest_file.symlink_to(src_file)
                                print(f"  Backed up & linked: {dest_file} -> {src_file}")
                        else:
                            print(
                                "  [WARNING] Target already exists as a regular file: "
                                f"{dest_file} (use -f to replace)"
                            )
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
        for _severity, pkg, msg in problems:
            print(f"  [DRIFT] {pkg}: {msg}")
        for _severity, pkg, msg in notes:
            print(f"  [note]  {pkg}: {msg}")
        if problems:
            print(f"\n{len(problems)} file(s) need attention, {len(notes)} note(s).")
            exit_code = 1
        else:
            print(
                f"Clean: no drift across {len(pkgs)} package(s)"
                + (f", {len(notes)} note(s)." if notes else ".")
            )
        return exit_code

    if backup_dir and backup_dir.exists():
        print(f"\nOriginal files backed up to: {backup_dir}")

    if exit_code:
        print("\nCompleted with warnings.")
    else:
        print("Completed successfully!")
    return exit_code


def main() -> int:
    target_dir = Path(os.environ.get("HOME", str(Path.home())))
    action = "stow"
    dry_run = False
    force = False
    run_deps = False
    run_update = False
    selected_pkgs: list[str] = []
    # Distinguishes "user asked for nothing" from "user asked, nothing matched".
    selector_given = False

    args = sys.argv[1:]
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--core":
            selector_given = True
            selected_pkgs.extend(CORE_PKGS)
            i += 1
        elif arg == "--google":
            selector_given = True
            selected_pkgs.extend(GOOGLE_PKGS)
            i += 1
        elif arg == "--all":
            selector_given = True
            selected_pkgs.extend(CORE_PKGS)
            selected_pkgs.extend(GOOGLE_PKGS)
            i += 1
        elif arg == "--deps":
            run_deps = True
            i += 1
        elif arg == "--update":
            run_update = True
            i += 1
        elif arg == "--deps-only":
            action = "deps-only"
            run_deps = True
            i += 1
        elif arg == "--update-only":
            action = "update-only"
            run_update = True
            i += 1
        elif arg in ("-f", "--force", "--adopt"):
            force = True
            i += 1
        elif arg in ("-R", "--restow"):
            action = "restow"
            i += 1
        elif arg in ("-D", "--delete", "--unstow"):
            action = "delete"
            i += 1
        elif arg in ("-s", "--status", "--check"):
            action = "status"
            i += 1
        elif arg in ("-l", "--list"):
            print(f"Core Packages:   {' '.join(CORE_PKGS)}")
            if GOOGLE_PKGS:
                print(f"Google Packages: {' '.join(GOOGLE_PKGS)}")
            return 0
        elif arg == "--list-packages":
            # Machine-readable counterpart to -l: bare names, one per line, no
            # headings. Used by verification scripts so the package list stays
            # defined in one place -- here.
            subset = args[i + 1] if (i + 1) < len(args) else "all"
            if subset == "core":
                for p in CORE_PKGS:
                    print(p)
            elif subset == "google":
                for p in GOOGLE_PKGS:
                    print(p)
            elif subset == "all":
                for p in CORE_PKGS + GOOGLE_PKGS:
                    print(p)
            else:
                print(
                    f"Unknown package set: {subset} (expected core, google or all)",
                    file=sys.stderr,
                )
                return 1
            return 0
        elif arg == "--sync":
            action = "sync"
            i += 1
        elif arg in ("-n", "--dry-run"):
            dry_run = True
            i += 1
        elif arg in ("-t", "--target"):
            if i + 1 >= len(args):
                print("Option -t/--target requires a directory argument", file=sys.stderr)
                return 1
            target_dir = Path(args[i + 1])
            i += 2
        elif arg in ("-h", "--help"):
            show_help(target_dir)
            return 0
        elif arg.startswith("-"):
            print(f"Unknown option: {arg}", file=sys.stderr)
            show_help(target_dir)
            return 1
        else:
            selector_given = True
            selected_pkgs.append(arg)
            i += 1

    if not selected_pkgs:
        if selector_given:
            # A selector was given but matched nothing -- e.g. --google in a public
            # checkout, which has no work packages. Silently falling back to --core
            # here would stow something the user did not ask for.
            print("No packages matched the given selection; nothing to do.")
            return 0
        print("No packages specified. Defaulting to --core.")
        selected_pkgs.extend(CORE_PKGS)

    # Remove duplicates while preserving order
    unique_pkgs = list(dict.fromkeys(selected_pkgs))

    # Ensure the common target directories exist. Package-specific directories are
    # created on demand as each file is deployed, so nothing package-specific needs
    # to be listed here.
    for sub in (".config", ".local/bin", ".ssh/conf.d"):
        (target_dir / sub).mkdir(parents=True, exist_ok=True)

    native_rc = 0
    if action not in ("deps-only", "update-only"):
        # Decide between system GNU Stow and the native implementation.
        #
        # GNU Stow is symlink-only and has no notion of content drift, so it cannot
        # service copy-mode files, 'status' or 'sync'. Silently letting it symlink a
        # file the package explicitly marked copy-mode would reintroduce exactly the
        # write-back bug copy mode exists to prevent, so prefer the native path
        # whenever copy mode is involved.
        use_native = True
        if shutil.which("stow") is not None:
            use_native = False
            if action in ("status", "sync"):
                use_native = True
            else:
                for pkg in unique_pkgs:
                    if (DOTFILES_DIR / pkg / MANIFEST).is_file():
                        print(
                            f"Note: package '{pkg}' declares copy-mode files; using the native"
                        )
                        print(
                            "      implementation instead of GNU Stow (which is symlink-only)."
                        )
                        use_native = True
                        break

        if not use_native:
            stow_cmd = ["stow", "-v", "-d", str(DOTFILES_DIR), "-t", str(target_dir)]
            if dry_run:
                stow_cmd.append("-n")
            if force:
                stow_cmd.append("--adopt")
            if action == "restow":
                stow_cmd.append("-R")
            elif action == "delete":
                stow_cmd.append("-D")
            stow_cmd.extend(unique_pkgs)

            print("Using system GNU Stow...")
            res = subprocess.run(stow_cmd, check=False)
            if res.returncode != 0:
                return res.returncode
            print("Done!")
        else:
            if action not in ("status", "sync"):
                print("Running native symlink manager...")
            native_rc = run_native_engine(
                dotfiles_dir=DOTFILES_DIR,
                target_dir=target_dir,
                action=action,
                dry_run=dry_run,
                force=force,
                pkgs=unique_pkgs,
            )
            # 'status' is a query: its exit code is the answer, so report it now.
            # For the mutating actions a non-zero code means "some files were skipped";
            # remember it for the final exit but keep going so --deps still runs.
            if action == "status":
                return native_rc

    if run_deps and not dry_run:
        print("\nInstalling external dependencies for selected packages...")
        for pkg in unique_pkgs:
            res = subprocess.run(
                [str(DOTFILES_DIR / "scripts" / "deps.sh"), pkg, "install"],
                check=False,
            )
            if res.returncode != 0:
                return res.returncode

    if run_update and not dry_run:
        print("\nUpdating external dependencies for selected packages...")
        for pkg in unique_pkgs:
            res = subprocess.run(
                [str(DOTFILES_DIR / "scripts" / "deps.sh"), pkg, "update"],
                check=False,
            )
            if res.returncode != 0:
                return res.returncode

    return native_rc


if __name__ == "__main__":
    sys.exit(main())
