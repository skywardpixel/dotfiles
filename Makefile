# Deploy dotfiles with GNU Stow.
#
# Stow's own options live in .stowrc (--target=~ --no-folding), so running
# plain `stow <pkg>` / `stow -D <pkg>` from this directory does exactly what
# `make` does. This file only adds package sets, copy-mode files and helpers.

CORE_PKGS := bin emacs eza ghostty git helix herdr nvim ssh tmux vim zsh

# Filled in by the optional site overlay (google.mk, absent in a public checkout).
GOOGLE_PKGS :=

# Files deployed as regular copies instead of symlinks, as <package>/<path>.
# For apps that rewrite their config with a temp file + rename(2), which
# replaces a symlink with a regular file and silently orphans the repo copy.
# Each must also be listed in its package's .stow-local-ignore so Stow skips it.
COPY_FILES :=

-include google.mk

ALL_PKGS := $(CORE_PKGS) $(GOOGLE_PKGS)
TARGET ?= $(HOME)
STOW := stow -t $(TARGET)

.PHONY: help all core google restow unstow dry-run status sync check list list-core \
        deps deps-core deps-google update update-core update-google

help:
	@echo "Modular Dotfiles (GNU Stow; options in .stowrc)"
	@echo ""
	@echo "  make all          - Stow all packages"
ifneq ($(GOOGLE_PKGS),)
	@echo "  make core         - Stow core packages"
	@echo "  make google       - Stow work overlay packages (google.mk)"
endif
	@echo "  make restow       - Restow all packages (prune dead links, add new ones)"
	@echo "  make unstow       - Remove all symlinks (copies are left in place)"
	@echo "  make dry-run      - Show what 'make all' would do"
	@echo "  make status       - Report de-linked files, conflicts and diverged copies"
	@echo "  make sync         - Keep \$$HOME's versions (pull them into the repo; review with git diff)"
	@echo "  make list         - List packages, one per line"
	@echo "  make check        - Parse every zsh file and assert the shell starts clean"
	@echo ""
	@echo "  make deps / update          - Install / update external dependencies"
	@echo "  make deps-<pkg> / update-<pkg>"
	@echo ""
	@echo "One-off, from this directory:  stow <pkg>   stow -D <pkg>   stow -R <pkg>"

# $(call copies,<packages>) -- the COPY_FILES belonging to those packages.
copies = $(filter $(addsuffix /%,$(1)),$(COPY_FILES))

# $(call deploy,<stow flags>,<packages>) -- stow, then place copy-mode files.
# A copy is written only when the target is missing; one that differs is
# reported and left alone, since without history we cannot tell who is right.
define deploy
	$(STOW) $(1) $(2)
	@for f in $(call copies,$(2)); do \
	  dest="$(TARGET)/$${f#*/}"; \
	  if [ ! -e "$$dest" ]; then \
	    mkdir -p "$$(dirname "$$dest")" && cp "$$f" "$$dest" && echo "COPY: $$dest"; \
	  elif ! cmp -s "$$f" "$$dest"; then \
	    echo "CONFLICT (copy): $$dest differs from $$f"; \
	    echo "  keep \$$HOME's: make sync    keep the repo's: rm $$dest && make"; \
	  fi; \
	done
endef

all:
	$(call deploy,,$(ALL_PKGS))

core:
	$(call deploy,,$(CORE_PKGS))

google:
	$(call deploy,,$(GOOGLE_PKGS))

restow:
	$(call deploy,-R,$(ALL_PKGS))

unstow:
	$(STOW) -D $(ALL_PKGS)

dry-run:
	$(STOW) -n -v $(ALL_PKGS)

# A dry-run restow makes Stow report every conflict: files an app has
# replaced with a regular file ("de-linked"), or foreign files in the way.
status:
	@rc=0; \
	out=$$($(STOW) -n -R $(ALL_PKGS) 2>&1) || rc=1; \
	printf '%s\n' "$$out" | grep -v '^WARNING: in simulation mode' || true; \
	for f in $(call copies,$(ALL_PKGS)); do \
	  dest="$(TARGET)/$${f#*/}"; \
	  if [ ! -e "$$dest" ]; then echo "copy not deployed: $$dest"; rc=1; \
	  elif ! cmp -s "$$f" "$$dest"; then echo "copy differs: diff $$dest $$f"; rc=1; fi; \
	done; \
	if [ $$rc = 0 ]; then echo "Clean."; fi; \
	exit $$rc

# Keep $HOME's versions: --adopt moves conflicting files into the repo and
# links them; differing copies are copied back. Review with `git diff`.
sync:
	$(STOW) --adopt $(ALL_PKGS)
	@for f in $(call copies,$(ALL_PKGS)); do \
	  dest="$(TARGET)/$${f#*/}"; \
	  if [ -e "$$dest" ] && ! cmp -s "$$f" "$$dest"; then \
	    cp "$$dest" "$$f" && echo "ADOPT (copy): $$dest -> $$f"; \
	  fi; \
	done

check:
	@./scripts/check-shell.sh

list:
	@printf '%s\n' $(ALL_PKGS)

list-core:
	@printf '%s\n' $(CORE_PKGS)

deps:
	@for p in $(ALL_PKGS); do ./scripts/deps.sh $$p install || exit; done
deps-core:
	@for p in $(CORE_PKGS); do ./scripts/deps.sh $$p install || exit; done
deps-google:
	@for p in $(GOOGLE_PKGS); do ./scripts/deps.sh $$p install || exit; done
update:
	@for p in $(ALL_PKGS); do ./scripts/deps.sh $$p update || exit; done
update-core:
	@for p in $(CORE_PKGS); do ./scripts/deps.sh $$p update || exit; done
update-google:
	@for p in $(GOOGLE_PKGS); do ./scripts/deps.sh $$p update || exit; done

# Single package, e.g. `make deps-vim` / `make update-tmux`. Explicit rules
# above take precedence, so deps-core/-google are unaffected.
deps-%:
	@./scripts/deps.sh $* install
update-%:
	@./scripts/deps.sh $* update
