# Modular Dotfiles (GNU Stow)

A clean, modular cross-platform dotfiles configuration managed with [GNU Stow](https://www.gnu.org/software/stow/).

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
- **`tmux/`**: Tmux configuration with TokyoNight styling.
- **`vim/`**: Minimal Vim configuration with vim-plug support.
- **`zsh/`**: Zsh environment (`.zshrc`, `.zshenv`, `.zprofile`, `.aliases`, `.env`, a framework-free async prompt, zsh-abbr, symlink-aware function autoloading).

---

## 🚀 Installation & Usage

```bash
# 1. Clone repository:
git clone <repo_url> ~/dotfiles
cd ~/dotfiles

# 2. Stow all packages:
make all
# or: ./stow.sh

# 3. Install external dependencies (Vim plugins, TPM, Ghostty shaders, Antidote):
make deps
# or: ./stow.sh --deps

# 4. Upgrade / update all external plugins & dependencies:
make update
# or: ./stow.sh --update

# Restow / update symlinks:
make restow

# Unstow:
make unstow

# Check for drift -- symlinks an application has silently replaced with a
# regular file (some apps rewrite their own config via a temp file + rename,
# which destroys the symlink and orphans the copy in this repo):
make status
```

---

## 🔄 Updating

Releases are published as ordinary commits on top of each other, so a plain pull works:

```bash
git pull
make restow     # pick up any files that were added, moved or removed
```

`make restow` matters: `git pull` updates the repository, but symlinks for
newly added files are only created when you restow.

<details>
<summary>If <code>git pull</code> refuses to merge</summary>

Releases before 2026-09-22 were published as unrelated orphan commits, so a clone
from that era has no common ancestor with current `main`. Re-sync once with:

```bash
git fetch origin
git reset --hard origin/main
make restow
```

This discards local modifications to tracked files. Keep your own changes in
`*.local` files instead — `.zshrc` and friends source them if present, and they
are not tracked here.
</details>
