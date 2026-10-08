##### OPTIONS ##################################################################

setopt auto_cd auto_pushd pushd_ignore_dups pushd_minus pushd_silent
DIRSTACKSIZE=20

setopt extended_glob glob_dots numeric_glob_sort no_nomatch

setopt interactive_comments
setopt no_beep
setopt no_flow_control

bindkey -e

##### HISTORY ##################################################################

HISTFILE=${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history
HISTSIZE=100000
SAVEHIST=100000
[[ -d ${HISTFILE:h} ]] || mkdir -p ${HISTFILE:h}

setopt extended_history
setopt inc_append_history
setopt share_history
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_reduce_blanks
setopt hist_verify
setopt hist_expire_dups_first

##### COMPLETION ###############################################################

autoload -Uz compinit
() {
  local dump=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump
  [[ -d ${dump:h} ]] || mkdir -p ${dump:h}
  if [[ -n ${dump}(#qN.mh-24) ]]; then
    compinit -C -d $dump
  else
    compinit -d $dump
    { zcompile -R -- $dump } &!
  fi
}

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' \
                                    'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose true
zstyle ':completion:*:descriptions' format '%F{244}%d%f'
zstyle ':completion:*:warnings'     format '%F{203}no matches%f'
zstyle ':completion:*:*:*:*:processes' command 'ps -u $USER -o pid,user,comm -w'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache

##### PROMPT ###################################################################
# Must load before plugins so they wrap the transient-prompt accept-line widget.

for _f in ${XDG_CONFIG_HOME:-$HOME/.config}/zsh/prompt{,.google,.local}.zsh(N); do source $_f; done
unset _f
prompt_enable_transient

##### PLUGINS ##################################################################

if [[ ! -d ~/.antidote ]]; then
  git clone --depth=1 https://github.com/mattmc3/antidote.git ~/.antidote
fi

ABBR_SET_EXPANSION_CURSOR=1

source ~/.antidote/antidote.zsh
antidote load

##### KEYBINDS #################################################################
# Emacs keymap already provides Alt+b/f/d, Alt+Backspace, C-a/e/k/u/w, etc.
# The sequences below are what terminals send for keys emacs mode leaves unbound.

autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search     # Up
bindkey '^[[B' down-line-or-beginning-search   # Down
bindkey '^P'   up-line-or-beginning-search     # Ctrl+p
bindkey '^N'   down-line-or-beginning-search   # Ctrl+n

bindkey '^[[1;5C' forward-word                 # Ctrl+Right
bindkey '^[[1;5D' backward-word                # Ctrl+Left
bindkey '^[[3~'   delete-char                  # Delete
bindkey '^[[H'    beginning-of-line            # Home
bindkey '^[[F'    end-of-line                  # End

autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line               # Ctrl+x Ctrl+e: edit in $EDITOR

copy-buffer-to-clipboard() { print -rn -- $BUFFER | clip }
zle -N copy-buffer-to-clipboard
bindkey '^Xy' copy-buffer-to-clipboard         # Ctrl+x y: copy line to clipboard

##### TOOLS ####################################################################

FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS \
  --highlight-line \
  --info=inline-right \
  --ansi \
  --layout=reverse \
  --border=none \
  --color=bg+:#283457 \
  --color=bg:#16161e \
  --color=border:#27a1b9 \
  --color=fg:#c0caf5 \
  --color=gutter:#16161e \
  --color=header:#ff9e64 \
  --color=hl+:#2ac3de \
  --color=hl:#2ac3de \
  --color=info:#545c7e \
  --color=marker:#ff007c \
  --color=pointer:#ff007c \
  --color=prompt:#2ac3de \
  --color=query:#c0caf5:regular \
  --color=scrollbar:#27a1b9 \
  --color=separator:#ff9e64 \
"

if (( $+commands[fzf] )); then
  source <(fzf --zsh)
fi
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi
if (( $+commands[mise] )); then
  eval "$(mise activate zsh)"
fi

##### ALIASES ##################################################################

if [[ -f ~/.aliases ]]; then
  source ~/.aliases
fi
