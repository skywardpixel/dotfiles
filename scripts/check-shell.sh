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

# Capture startup $? first, then emit a canary token on fd 2. This catches both
# directions of stderr breakage:
#   - Extra text before the canary => startup printed an error/warning.
#   - Missing canary               => startup closed or redirected fd 2.
STDERR_CANARY="__STDERR_INTACT__"
STARTUP_Probe='s=$?; print -r -u2 -- '"'$STDERR_CANARY'"'; exit $s'
STARTUP_STDERR="$(zsh -i -c "$STARTUP_Probe" 2>&1 >/dev/null)"
STARTUP_STATUS=$?

if (( STARTUP_STATUS == 0 )); then
  printf 'ok    startup status: 0 (%s)\n' "$DEPLOYED"
else
  fail "startup status: $STARTUP_STATUS (expected 0)"
  echo "        the last command run during startup failed; find it with:" >&2
  echo "        zsh -i -x -c 'print \$?' 2>&1 | tail -20" >&2
fi

if [[ "$STARTUP_STDERR" == "$STDERR_CANARY" ]]; then
  printf 'ok    startup stderr: empty and fd 2 intact\n'
elif [[ -z "$STARTUP_STDERR" ]]; then
  fail "startup stderr: fd 2 was closed or redirected to /dev/null during startup"
else
  fail "startup stderr: not empty"
  printf '%s\n' "${STARTUP_STDERR%"$STDERR_CANARY"}" | sed 's/^/        /' >&2
fi

# Also verify the isolated public (--core only) startup path in a clean sandbox
# without any google-* overlay files, so a passing $HOME check on a work machine
# (where ~/.aliases.google is stowed) cannot mask a failure in the public config.
SANDBOX_HOME="$(mktemp -d)"
./stow.py --core -t "$SANDBOX_HOME" >/dev/null 2>&1
if [[ -d "$HOME/.antidote" ]]; then
  ln -s "$HOME/.antidote" "$SANDBOX_HOME/.antidote"
fi
if [[ -d "${XDG_CACHE_HOME:-$HOME/.cache}/antidote" ]]; then
  mkdir -p "$SANDBOX_HOME/.cache"
  ln -s "${XDG_CACHE_HOME:-$HOME/.cache}/antidote" "$SANDBOX_HOME/.cache/antidote"
fi
CORE_STDERR="$(HOME="$SANDBOX_HOME" ZDOTDIR="$SANDBOX_HOME" zsh -d -i -c "$STARTUP_Probe" 2>&1 >/dev/null)"
CORE_STATUS=$?
rm -rf "$SANDBOX_HOME"

if (( CORE_STATUS == 0 )) && [[ "$CORE_STDERR" == "$STDERR_CANARY" ]]; then
  printf 'ok    core-only startup: 0, empty stderr, fd 2 intact (isolated public sandbox)\n'
else
  fail "core-only startup: status=$CORE_STATUS (expected 0, empty stderr, fd 2 intact)"
  [[ -n "$CORE_STDERR" && "$CORE_STDERR" != "$STDERR_CANARY" ]] &&
    printf '%s\n' "${CORE_STDERR%"$STDERR_CANARY"}" | sed 's/^/        /' >&2
fi

##### 4. PROMPT ASYNC & FD INVARIANTS ##########################################
#
# `zsh -i -c exit` exits before precmd/zle callbacks ever fire, AND a check
# that only asserts "stderr is empty" is trivially satisfied if a prompt hook
# accidentally redirects fd 2 to /dev/null (e.g. a bare `exec {fd}<&- 2>/dev/null`).
# Exercise both `_pr_async_done` and `_pr_async_stop` inside this git repo and
# verify that:
#   - `_pr_fd` is allocated and cleanly closed (no FD leak),
#   - `PROMPT_VCS` is populated by the async worker, and
#   - interactive `stderr` (fd 2) still delivers output afterward.

PROMPT_CHECK_OUT="$(
  zsh -f -c '
    source ./zsh/.config/zsh/prompt.zsh || exit 10
    # 1. Start async worker via precmd and let _pr_async_done harvest it.
    _pr_precmd
    (( _pr_fd > 2 )) || exit 11
    local fd1=$_pr_fd
    _pr_async_done $_pr_fd
    (( _pr_fd == 0 )) || exit 12
    [[ ! -e /dev/fd/$fd1 ]] || exit 13
    [[ -n $PROMPT_VCS ]] || exit 14

    # 2. Start a second async worker and exercise the _pr_async_stop path.
    _pr_precmd
    (( _pr_fd > 2 )) || exit 15
    local fd2=$_pr_fd
    _pr_async_stop
    (( _pr_fd == 0 )) || exit 16
    [[ ! -e /dev/fd/$fd2 ]] || exit 17

    # 3. Prove fd 2 (stderr) was not redirected to /dev/null.
    print -r -u2 -- "__STDERR_INTACT__"
  ' 2>&1 >/dev/null
)"
PROMPT_CHECK_STATUS=$?

if (( PROMPT_CHECK_STATUS == 0 )) && [[ "$PROMPT_CHECK_OUT" == "__STDERR_INTACT__" ]]; then
  printf 'ok    prompt async: VCS segment renders, no FD leaks, stderr intact\n'
else
  fail "prompt async: status=$PROMPT_CHECK_STATUS output=${PROMPT_CHECK_OUT:-<empty>}"
fi

##### 5. OPTIONAL OVERLAY CHECKS ##############################################
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
