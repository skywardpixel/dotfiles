# Homebrew lives here on macOS only. `if` rather than `[[ ... ]] &&` so that
# its absence on Linux -- the normal case -- is not reported as a failure by
# the last command of a login shell's startup.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
