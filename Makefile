.PHONY: help all restow unstow list dry-run deps deps-all update update-all $(addprefix deps-, $(PACKAGES)) $(addprefix update-, $(PACKAGES))

TARGET ?= $(HOME)
STOW = stow -v -t $(TARGET)

PACKAGES = bin emacs eza ghostty git helix nvim ssh tmux vim zsh

help:
	@echo "Modular Dotfiles (GNU Stow)"
	@echo ""
	@echo "Usage:"
	@echo "  make all          - Stow all packages ($(PACKAGES))"
	@echo "  make restow       - Restow all packages"
	@echo "  make unstow       - Unstow all packages"
	@echo "  make dry-run      - Simulate stowing without making changes"
	@echo "  make list         - List available packages"
	@echo ""
	@echo "Dependencies & Upgrades:"
	@echo "  make deps         - Install dependencies for all packages"
	@echo "  make deps-<pkg>   - Install dependencies for a specific package (e.g. make deps-vim)"
	@echo "  make update       - Update dependencies for all packages"
	@echo "  make update-<pkg> - Update dependencies for a specific package (e.g. make update-tmux)"

all:
	@mkdir -p $(TARGET)/.config $(TARGET)/.local/bin $(TARGET)/.ssh $(TARGET)/.ssh/conf.d
	$(STOW) $(PACKAGES)

restow:
	$(STOW) -R $(PACKAGES)

unstow:
	$(STOW) -D $(PACKAGES)

dry-run:
	$(STOW) -n $(PACKAGES)

list:
	@echo "Packages: $(PACKAGES)"

deps: deps-all
deps-all: $(addprefix deps-, $(PACKAGES))

update: update-all
update-all: $(addprefix update-, $(PACKAGES))

deps-%:
	@./scripts/deps.sh $* install

update-%:
	@./scripts/deps.sh $* update
