# Modular Dotfiles (GNU Stow)

A clean, modular cross-platform dotfiles configuration managed with [GNU Stow](https://www.gnu.org/software/stow/). Designed to run standalone on personal Linux / macOS machines while supporting a purely additive site overlay (see `README.google.md` when present) that layers work-specific packages on top without touching a single core file.

---

## 📦 Included Packages

- **`bin/`**: Universal scripts (`clip`, `osc52.sh`).
- **`emacs/`**: Emacs configuration (`init.el`, `early-init.el`, `lisp/`).
- **`eza/`**: Theme for `eza`.
- **`ghostty/`**: Terminal configuration with TokyoNight styling.
- **`git/`**: Git config with sensible aliases and global ignore.
- **`helix/`**: Modal editor settings.
- **`nvim/`**: Neovim configuration (Lazy.nvim, plugins, options, keymaps, ftplugins).
- **`ssh/`**: SSH base config with `Include ~/.ssh/conf.d/*`.
- **`tmux/`**: Tmux configuration with TokyoNight styling and sensible defaults.
- **`vim/`**: Minimal Vim configuration with vim-plug support.
- **`zsh/`**: Zsh environment (`.zshrc`, `.zshenv`, `.zprofile`, `.aliases`, `.env`, a framework-free async prompt in `.config/zsh/prompt.zsh`, `zsh-abbr`, symlink-aware function autoloading).

> [!NOTE]
> The package sets live in one place each: core packages inline in `stow.py`, and optional site-overlay packages in `packages.google` (absent in a public checkout, so `--all`, `--core`, and `--google` all resolve cleanly without maintaining separate copies of `stow.py` or `Makefile`).

---

## 🚀 Quick Start

### 1. Prerequisites
Ensure `stow` and `git` are installed (though `./stow.py` also includes a built-in native fallback when the `stow` binary is absent):
- **Arch / Omarchy**: `sudo pacman -S stow`
- **Debian / Ubuntu**: `sudo apt install stow`
- **macOS**: `brew install stow`

### 2. Usage

You can use either the `Makefile` or `./stow.py`.

`./stow.py` is the single implementation; the `Makefile` is a thin alias layer over it holding **no package lists of its own** (`make core` is `./stow.py --core`). Use `make` for the common workflows, and `./stow.py` directly when you need flags `make` does not surface (`-f`, `-t`, or a specific list of packages).

#### Using `Makefile`:
```bash
# Stow all available packages
make all

# Install external dependencies (Vim-Plug, TPM, Ghostty shaders, Antidote)
make deps

# Install or update external dependencies for a single package
make deps-vim
make update-tmux

# Upgrade all external dependencies
make update

# Simulate stowing without making changes
make dry-run

# Restow / prune dead links
make restow

# Unstow / remove symlinks
make unstow

# Report de-linked symlinks and diverged copy-mode files
make status

# Pull app-written changes to copy-mode files back into the repo
make sync

# Verify every zsh file parses and interactive shell startup exits 0 with clean stderr
make check
```

#### Using `./stow.py`:
```bash
# Stow core packages
./stow.py --core

# Stow and install dependencies together
./stow.py --all --deps

# Install or update dependencies only
./stow.py --deps-only vim tmux
./stow.py --update-only

# Stow specific packages
./stow.py nvim zsh tmux

# Force adopt existing regular files (with automatic backup)
./stow.py -f --all

# Dry-run
./stow.py -n --core
```

---

## 🔄 Updating

Releases are ordinary commits on a linear branch, so a plain pull works:

```bash
git pull
make restow     # pick up any files that were added, moved, or removed
```

`make restow` matters: `git pull` updates the repository, but symlinks for newly added files are only created when you restow. Keep machine-specific tweaks in untracked `*.local` files (`.zshrc`, `.zshenv`, `.aliases`, and `prompt.zsh` all source their `.local` counterparts if present).

---

## 🔍 Technical Details

### Prompt Modularization
The prompt is modular along two independent axes: **core vs. site overlay** (so the core prompt works unchanged anywhere) and **engine vs. VCS backend** (so each version control system is self-contained).

| File | Package | Contents |
|---|---|---|
| `.config/zsh/prompt.zsh` | `zsh` | Engine: appearance, directory segment, async worker, mtime cache |
| `.config/zsh/prompt/vcs.zsh` | `zsh` | VCS framework: backend registry, root discovery, cache fingerprinting |
| `.config/zsh/prompt/vcs-{git,hg,jj}.zsh` | `zsh` | One self-contained backend each |
| `.config/zsh/prompt.*.zsh` | *(overlay / local)* | Optional site and per-machine overrides, sourced if present |

`zsh/.zshrc` sources `prompt.zsh` unconditionally and optional overlay files only if they exist.

#### VCS backends
Backends are loaded by name, and the list is the **detection order** — the first backend whose root test matches wins:

```zsh
PROMPT_VCS_MODULES=( jj hg git )    # set before sourcing prompt.zsh
```

`jj` must precede `git`, because a colocated `jj` repository contains both `.jj` and `.git` and the `jj` segment is the more specific one. Dropping a name means that backend is never loaded, so you pay nothing for it — not even the `stat()` probing for its marker directory. A module also declines to register itself when its binary is absent.

Each backend module owns its own colours and glyphs and implements three functions:

```zsh
_pr_vcs_<name>_root DIR      # is DIR a repo root of this type?
_pr_vcs_<name>_render ROOT   # print the segment (runs in the background job)
_pr_vcs_<name>_watch ROOT    # optional: files whose mtimes validate the cache
```

Omitting `_watch` means "cannot be cached, always re-query" — which is what `git` does, since editing a working-tree file never touches `.git`. `hg` and `jj` declare watch files, making the steady state cost zero forks. The whole VCS layer is optional: with `prompt/vcs.zsh` absent the prompt still works and simply shows no VCS segment.

#### Site overlay hooks
The core engine knows nothing about any specific work environment; an overlay plugs in through hooks that communicate via `REPLY`/`reply` (never stdout, so calling them costs no fork):

```zsh
prompt_dir_segment           # replace the directory segment
prompt_vcs_root_hint         # "<type> <root>", skip the upward .jj/.hg scan
prompt_vcs_watch_extra R T   # extra files whose mtime invalidates the cache
prompt_hg_extra R            # extra hg text; reads $_pr_hg_extra
prompt_jj_extra R            # extra jj text
```

Two seams avoid duplicating VCS queries in an overlay: `PROMPT_HG_EXTRA_TEMPLATE` appends template keywords to the core's existing `hg log` call (so extra metadata costs no second invocation), and `prompt_vcs_watch_extra` contributes additional cache-invalidation files.

### Symlink-Aware Shell Functions (`zfuncs`)
Standard Zsh function-autoload snippets scan using the `(N.:t)` glob qualifier. Because `.` matches only regular plain files, symlinked function files created by Stow are silently ignored.

`zsh/.zshrc` uses the symlink-following qualifier `(N-.:t)`:
```zsh
() {
  local fndir=${XDG_CONFIG_HOME:-$HOME/.config}/zsh/functions
  if [[ -d $fndir ]]; then
    fpath=($fndir $fpath)
    autoload -Uz $fndir/*(N-.:t)
  fi
}
```
The `-` modifier makes `.` apply after symlink resolution, so custom functions from `zsh` and any overlay package autoload seamlessly.

### Write-Back Config Files

Some applications *rewrite* their own config by writing a temporary file and `rename(2)`-ing it over the target. Because `rename(2)` replaces the **path**, a Stow symlink at that path is destroyed and silently replaced by a regular file — after which the repo stops receiving updates and `git status` stays clean, because the broken link lives in `$HOME`, outside the work tree.

> [!WARNING]
> This is a silent failure mode. Files an application only *reads* are unaffected; only temp-file + `rename(2)` writers are at risk.

Three strategies, best first:

| # | Strategy | Drift | Ongoing cost |
| :-- | :--- | :--- | :--- |
| 1 | **Relocate** the app's config into the checkout | structurally impossible | none |
| 2 | **Copy mode** (`.stow-copy`) + `make status` / `make sync` | detected | must sync after the app writes |
| 3 | Plain symlink | **silent loss** | none — until it breaks |

> [!IMPORTANT]
> Copy mode does **not** capture the app's write automatically; it makes the divergence *detectable* and one command to sync. Prefer strategy 1 whenever the app offers a way to relocate its config path.

#### 1. Relocation — `zsh-abbr`

`zsh-abbr` lets you choose its storage file via `ABBR_USER_ABBREVIATIONS_FILE`, so the symlink can be removed from the write path (`zsh/.zshrc`):

```zsh
() {
  local abbr_file=${${(%):-%x}:A:h}/.config/zsh-abbr/user-abbreviations
  [[ -f $abbr_file ]] && export ABBR_USER_ABBREVIATIONS_FILE=$abbr_file
}
```

`%x` is the file currently being sourced and `:A` resolves it through the Stow symlink, pointing straight into the checkout regardless of where the repo was cloned. `abbr add` then edits the tracked file in place and shows up in `git status`. For session-only abbreviations that should *not* be persisted to the shared file, use `abbr -S`.

#### 2. Copy mode (`.stow-copy`)

When an application offers no env var, flag, `XDG_CONFIG_HOME` support, or `include` directive, a package can declare a `.stow-copy` manifest of package-relative globs to deploy as regular file copies instead of symlinks. Everything else in the package is still symlinked, and `stow.py` records the deployed file's hash under `.stow-state/` (gitignored, machine-local).

**Why the recorded hash matters.** A two-way repo↔target diff cannot distinguish a repo edit from an app write, so it cannot know which direction to sync. The recorded hash is the referee:

| repo == recorded | target == recorded | Meaning | Action |
| :--- | :--- | :--- | :--- |
| ✅ | ✅ | clean | — |
| ❌ | ✅ | you edited the repo | `./stow.py` applies it |
| ✅ | ❌ | the app wrote the target | `make sync` pulls it back |
| ❌ | ❌ | **both changed** | **refused** — diff and resolve by hand |

```bash
make status   # report drift; exits non-zero if anything needs action
make sync     # pull app-written changes back into the repo
```

`stow.py` refuses to overwrite an unsynced app write (`-f` overrides, backing the target up first), and `-D` refuses to delete one. `make status` also detects the original failure mode across *all* packages: any symlink an app has replaced with a regular file is reported as `DE-LINKED`.

### Neovim Modularization
Neovim's `lua/config/lazy.lua` dynamically checks whether an optional overlay directory (`lua/google-plugins`) exists before importing it:
```lua
local google_plugins_dir = vim.fn.stdpath("config") .. "/lua/google-plugins"
if (vim.uv or vim.loop).fs_stat(google_plugins_dir) then
  table.insert(plugins_spec, { import = "google-plugins" })
end
```
When only the core `nvim` package is stowed, the overlay directory is absent and omitted without any manual configuration changes.

### Shell Startup Checks

`make check` (`scripts/check-shell.sh`) makes three assertions:

| Check | Catches |
|---|---|
| `zsh -n` on every zsh file | parse errors, without executing anything — works in an unstowed checkout |
| interactive startup exits `0` | a trailing conditional whose test is false; **fails silently, printing nothing** |
| that startup's stderr is empty | missing commands and plugin breakage, which print but often leave `$?` at 0 |

The second check exists because of a subtle shell trap: `.zshrc` ended with `[[ -f ~/.aliases ]] && source ~/.aliases`, `.aliases` ended with the same shape for `~/.aliases.local`, and `~/.aliases.local` does not exist on every machine. zsh hands the status of the *last command run during startup* to the first prompt, so `exec zsh` returned 1 while printing nothing. Hence the rule: **a startup file's last statement must never be a bare `cond && cmd`.** Use `if`, which yields 0 when the condition is false but still propagates a real failure from the body.

> [!NOTE]
> Deliberately not a `ZERR` trap over the whole of startup. zsh disables that trap "while running initialization scripts" (see `ERR_EXIT` in the manual), so a trap installed inside `.zshrc` never fires — nor do `setopt err_exit` or `zsh -o err_exit`. Only `err_return` inside a function still works.
>
> Starting with `zsh -f` and sourcing the rc chain by hand dodges that restriction, and reports **225 failing commands in a completely healthy shell** — all of them `zsh-abbr` internals using non-zero as normal control flow (9 per `abbr` call site), with misattributed `funcfiletrace` line numbers. Hence three narrow assertions instead of one global trap.
