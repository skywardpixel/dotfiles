#!/bin/sh
# Copy stdin (or the arguments) to the terminal clipboard with OSC 52.
# Inside tmux, `set-clipboard on` forwards the sequence to the outer terminal.
if [ $# -gt 0 ]; then
  data=$(printf '%s' "$*" | base64 | tr -d '\n')
else
  data=$(base64 | tr -d '\n')
fi
printf '\033]52;c;%s\a' "$data"
