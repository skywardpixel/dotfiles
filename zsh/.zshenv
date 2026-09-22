typeset -U path
path=("$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/go/bin" $path)

[[ -f "$HOME/.env" ]] && source "$HOME/.env"
[[ -f "$HOME/.env.google" ]] && source "$HOME/.env.google"
[[ -f "$HOME/.env.local" ]] && source "$HOME/.env.local"
