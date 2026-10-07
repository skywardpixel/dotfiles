typeset -U path
path=("$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/go/bin" $path)

if [[ -f "$HOME/.env" ]]; then
  source "$HOME/.env"
fi
if [[ -f "$HOME/.env.google" ]]; then
  source "$HOME/.env.google"
fi
if [[ -f "$HOME/.env.local" ]]; then
  source "$HOME/.env.local"
fi
