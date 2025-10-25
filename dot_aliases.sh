##### COMMON UTILS #####

alias ls='ls --color=auto'
alias diff='diff --color=auto'
alias grep='grep --color=auto'
alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias path='echo -e ${PATH//:/\\n}'
alias du="ncdu --color dark -rr -x --exclude .git --exclude node_modules"
alias shortdate="date +%Y%m%d%H%M%S"
alias r4='rchar 4'

# Use osc52.sh as pbcopy if in a remote session.
if [[ -n "$SSH_TTY" || -n "$SHPOOL_SESSION_NAME" ]]; then
  alias pbcopy='osc52.sh'
fi
