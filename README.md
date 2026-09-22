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
```
