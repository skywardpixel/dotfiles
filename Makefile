.PHONY: help all restow unstow list dry-run status sync deps deps-all update update-all

TARGET ?= $(HOME)
# Delegate to ./stow.sh rather than calling `stow` directly: it falls back to a
# native implementation when the GNU Stow binary is absent, and understands
# .stow-copy (files deployed as copies because their app rewrites them).
STOW = ./stow.sh -t $(TARGET)

help:
	@echo "Modular Dotfiles"
	@echo ""
	@echo "Usage:"
	@echo "  make all          - Stow all packages"
	@echo "  make restow       - Restow all packages"
	@echo "  make unstow       - Unstow all packages"
	@echo "  make dry-run      - Simulate stowing without making changes"
	@echo "  make list         - List available packages"
	@echo ""
	@echo "Drift:"
	@echo "  make status       - Report de-linked symlinks and diverged copies"
	@echo "  make sync         - Pull app-written changes back into the repo"
	@echo ""
	@echo "Dependencies & Upgrades:"
	@echo "  make deps         - Install dependencies for all packages"
	@echo "  make deps-<pkg>   - Install dependencies for a specific package (e.g. make deps-vim)"
	@echo "  make update       - Update dependencies for all packages"
	@echo "  make update-<pkg> - Update dependencies for a specific package (e.g. make update-tmux)"

all:
	$(STOW) --all

restow:
	$(STOW) -R --all

unstow:
	$(STOW) -D --all

dry-run:
	$(STOW) -n --all

status:
	@$(STOW) -s --all

sync:
	@$(STOW) --sync --all

list:
	@./stow.sh --list

deps: deps-all
deps-all:
	@./stow.sh --deps-only --all

update: update-all
update-all:
	@./stow.sh --update-only --all

deps-%:
	@./stow.sh --deps-only $*

update-%:
	@./stow.sh --update-only $*
