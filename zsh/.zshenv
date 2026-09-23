typeset -U path
path=("$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/go/bin" $path)

# Optional environment fragments. `if` rather than `[[ ... ]] &&` because the
# latter reports a *missing* file as a failure, and a trailing false test here
# becomes the startup status of every shell. A fragment that exists but fails
# still reports its real status.
if [[ -f "$HOME/.env" ]]; then
  source "$HOME/.env"
fi
if [[ -f "$HOME/.env.google" ]]; then
  source "$HOME/.env.google"
fi
if [[ -f "$HOME/.env.local" ]]; then
  source "$HOME/.env.local"
fi
