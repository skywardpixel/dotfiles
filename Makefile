.PHONY: help all core google restow unstow list dry-run status sync check \
        deps deps-core deps-google deps-all update update-core update-google update-all

# This Makefile is a thin alias layer over ./stow.py -- it deliberately holds no
# package lists of its own. stow.py owns the package sets (core inline, work in
# packages.google), the symlink/copy logic and the drift tracking, so adding or
# removing a package is a one-line change there rather than an edit in two files
# that can silently disagree.
#
# Anything expressible here is expressible directly:
#   make core  ==  ./stow.py --core
# Use ./stow.py when you need flags this layer does not surface (-f, -t, or a
# specific package name).

TARGET ?= $(HOME)
STOW = ./stow.py -t $(TARGET)

help:
	@echo "Modular Dotfiles"
	@echo ""
	@echo "Usage:"
ifneq ($(wildcard packages.google),)
	@echo "  make core         - Stow core/universal packages"
	@echo "  make google       - Stow work overlay packages (packages.google)"
	@echo "  make all          - Stow all packages (core + work)"
else
	@echo "  make all          - Stow all packages"
endif
	@echo "  make restow       - Restow all packages"
	@echo "  make unstow       - Unstow all packages"
	@echo "  make dry-run      - Simulate stowing without making changes"
	@echo "  make list         - List available packages"
	@echo ""
	@echo "Drift (copy-mode files, see .stow-copy):"
	@echo "  make status       - Report de-linked symlinks and diverged copies"
	@echo "  make sync         - Pull app-written changes back into the repo"
	@echo ""
	@echo "Verification:"
	@echo "  make check        - Parse every zsh file and assert the shell starts clean"
	@echo ""
	@echo "Dependencies & Upgrades:"
	@echo "  make deps         - Install dependencies for all packages"
ifneq ($(wildcard packages.google),)
	@echo "  make deps-core    - Install dependencies for core packages"
	@echo "  make deps-google  - Install dependencies for work packages"
endif
	@echo "  make deps-<pkg>   - Install dependencies for a specific package (e.g. make deps-vim)"
	@echo "  make update       - Update dependencies for all packages"
ifneq ($(wildcard packages.google),)
	@echo "  make update-core  - Update dependencies for core packages"
endif
	@echo "  make update-<pkg> - Update dependencies for a specific package (e.g. make update-tmux)"
	@echo ""
	@echo "For flags this layer does not surface (-f, -t, or a subset of packages):"
	@echo "  ./stow.py -h"

core:
	$(STOW) --core

google:
	$(STOW) --google

all:
	$(STOW) --all

restow:
	$(STOW) -R --all

unstow:
	$(STOW) -D --all

dry-run:
	$(STOW) -n --all

# Report drift: symlinks an app has replaced with regular files, and copy-mode
# files that have diverged. Exits non-zero if anything needs action.
status:
	@$(STOW) -s --all

# Pull app-written changes to copy-mode files back into the repo.
sync:
	@$(STOW) --sync --all

# Parse every zsh file, then assert a real interactive startup exits 0 with
# nothing on stderr. Exits non-zero if any check fails.
check:
	@./scripts/check-shell.sh

list:
	@./stow.py --list

deps: deps-all
deps-all:
	@./stow.py --deps-only --all
deps-core:
	@./stow.py --deps-only --core
deps-google:
	@./stow.py --deps-only --google

update: update-all
update-all:
	@./stow.py --update-only --all
update-core:
	@./stow.py --update-only --core
update-google:
	@./stow.py --update-only --google

# Single package, e.g. `make deps-vim` / `make update-tmux`. Explicit rules
# above take precedence, so deps-core/-google/-all are unaffected.
deps-%:
	@./stow.py --deps-only $*
update-%:
	@./stow.py --update-only $*
