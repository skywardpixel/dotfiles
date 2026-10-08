typeset -U path
path=("$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/go/bin" $path)

for _f in ~/.env{,.google,.local}(N); do source $_f; done
unset _f
