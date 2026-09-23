#!/usr/bin/env bash
# Verify the shell configuration parses and starts cleanly.
#
# Three checks, in increasing order of what they can catch:
#
#   1. zsh -n on every zsh file in the repo. Parse only, nothing executed, so
#      it works in a checkout that has never been stowed.
#   2. The exit status of a real interactive startup. This is the one that
#      catches a trailing `[[ -f optional-file ]] && source optional-file`
#      whose test is false: zsh hands the status of the last command run
#      during startup to the first prompt, so the shell reports failure while
#      printing nothing at all.
#   3. stderr from that same startup must be empty. Most genuine breakage
#      (missing command, plugin blowing up) prints but does not set a status,
#      so this catches the complement of check 2.
#
# Deliberately NOT a ZERR trap over the whole of startup. zsh disables the
# trap "while running initialization scripts" anyway, and sourcing the rc
# chain by hand to dodge that reports ~225 failing commands in a healthy
# shell -- every one of them a plugin using non-zero as ordinary control
# flow. There is no signal in it to gate on.
#
# Usage: ./scripts/check-shell.sh     (or: make check)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$DOTFILES_DIR"

FAILURES=0

fail() {
  printf 'FAIL  %s\n' "$1" >&2
  FAILURES=$((FAILURES + 1))
}

if ! command -v zsh >/dev/null 2>&1; then
  echo "zsh not installed; nothing to check."
  exit 0
fi

##### 1. SYNTAX ###############################################################
#
# Discovered, not listed, so a new prompt module or function is covered the
# moment it is added. .zsh_plugins.txt is an antidote manifest rather than
# shell code, and zsh-abbr's store is generated data.

mapfile -t ZSH_FILES < <(
  find . -type f \
    \( -name '.zsh*' -o -name '.aliases*' -o -name '*.zsh' -o -path '*/zsh/functions/*' \) \
    -not -name '.zsh_plugins.txt' \
    -not -path '*/zsh-abbr/*' \
    -not -path './.git/*' \
    | sort
)

SYNTAX_FAILURES=0
for f in "${ZSH_FILES[@]}"; do
  if ! err="$(zsh -n "$f" 2>&1)"; then
    fail "syntax: ${f#./}"
    printf '%s\n' "$err" | sed 's/^/        /' >&2
    SYNTAX_FAILURES=$((SYNTAX_FAILURES + 1))
  fi
done
if (( SYNTAX_FAILURES == 0 )); then
  printf 'ok    syntax: %d zsh file(s) parse\n' "${#ZSH_FILES[@]}"
fi


##### 2 + 3. STARTUP ##########################################################
#
# These exercise the *deployed* config under $HOME, not the checkout, so say
# so when the two are not actually connected -- otherwise a green run here
# means nothing after someone edits the repo without restowing.

if [[ -L "$HOME/.zshrc" && "$(readlink -f "$HOME/.zshrc")" == "$DOTFILES_DIR"/* ]]; then
  DEPLOYED="this checkout"
else
  DEPLOYED="NOT this checkout -- run ./stow.py zsh"
fi

# `-c exit` exits with whatever $? already was, i.e. the status startup left
# behind. Capture stderr while discarding stdout: the 2>&1 must come first so
# it duplicates the still-captured stdout, before stdout goes to /dev/null.
STARTUP_STDERR="$(zsh -i -c exit 2>&1 >/dev/null)"
STARTUP_STATUS=$?

if (( STARTUP_STATUS == 0 )); then
  printf 'ok    startup status: 0 (%s)\n' "$DEPLOYED"
else
  fail "startup status: $STARTUP_STATUS (expected 0)"
  echo "        the last command run during startup failed; find it with:" >&2
  echo "        zsh -i -x -c 'print \$?' 2>&1 | tail -20" >&2
fi

if [[ -z "$STARTUP_STDERR" ]]; then
  printf 'ok    startup stderr: empty\n'
else
  fail "startup stderr: not empty"
  printf '%s\n' "$STARTUP_STDERR" | sed 's/^/        /' >&2
fi

# Also verify the isolated public (--core only) startup path in a clean sandbox
# without any google-* overlay files, so a passing $HOME check on a work machine
# (where ~/.aliases.google is stowed) cannot mask a failure in the public config.
SANDBOX_HOME="$(mktemp -d)"
./stow.py --core -t "$SANDBOX_HOME" >/dev/null 2>&1
if [[ -d "$HOME/.antidote" ]]; then
  ln -s "$HOME/.antidote" "$SANDBOX_HOME/.antidote"
fi
CORE_STDERR="$(HOME="$SANDBOX_HOME" ZDOTDIR="$SANDBOX_HOME" zsh -d -i -c exit 2>&1 >/dev/null)"
CORE_STATUS=$?
rm -rf "$SANDBOX_HOME"

if (( CORE_STATUS == 0 )) && [[ -z "$CORE_STDERR" ]]; then
  printf 'ok    core-only startup: 0, empty stderr (isolated public sandbox)\n'
else
  fail "core-only startup: status=$CORE_STATUS (expected 0, empty stderr)"
  [[ -n "$CORE_STDERR" ]] && printf '%s\n' "$CORE_STDERR" | sed 's/^/        /' >&2
fi

##### 4. OPTIONAL OVERLAY CHECKS ##############################################
#
# When the work overlay branch ('google') is checked out, scripts/check-google.py
# verifies that the 'main' base branch and core packages contain zero internal
# references, zero overlay files, and no private @google.com commit emails.

if [[ -x "$SCRIPT_DIR/check-google.py" ]]; then
  if ! "$SCRIPT_DIR/check-google.py"; then
    FAILURES=$((FAILURES + 1))
  fi
fi

##### RESULT ##################################################################

if (( FAILURES )); then
  printf '\n%d check(s) failed.\n' "$FAILURES" >&2
  exit 1
fi
echo "All checks passed."
