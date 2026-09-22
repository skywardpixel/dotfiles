# ~/.zshrc -- interactive shell configuration.
#
# Layout:
#   .zshenv   PATH and exported variables (all shells)
#   .zprofile login shells
#   .zshrc    this file: options, completion, plugins, prompt, keybinds
#
# Design notes:
#   * The prompt is ~/.config/zsh/prompt.zsh -- plain zsh, no framework, with a
#     background worker for VCS status. See the comments in that file.
#   * Antidote is kept, but only for the four plugins that genuinely need a
#     package manager. Everything Zephyr used to provide (options, history,
#     completion styling, keybinds) is written out below instead, because it is
#     about forty lines and far easier to reason about than eight plugins.

##### OPTIONS ##################################################################

# Navigation: `cd` by typing a directory name, keep a directory stack.
setopt auto_cd auto_pushd pushd_ignore_dups pushd_minus pushd_silent
DIRSTACKSIZE=20

# Globbing.
setopt extended_glob glob_dots numeric_glob_sort no_nomatch

# Misc.
setopt interactive_comments    # allow `# comment` on the command line
setopt no_beep
setopt no_flow_control         # free up C-s / C-q
setopt multios
unsetopt correct correct_all   # never second-guess a typed command

bindkey -e                     # emacs keymap; chosen before plugins add widgets

##### HISTORY ##################################################################

HISTFILE=${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history
HISTSIZE=100000
SAVEHIST=100000
[[ -d ${HISTFILE:h} ]] || mkdir -p ${HISTFILE:h}

setopt extended_history          # record timestamps and durations
setopt inc_append_history        # write as you go, not just at exit
setopt share_history             # ...and pick up other shells' commands
setopt hist_ignore_all_dups      # a repeated command only appears once
setopt hist_ignore_space         # " secret-command" stays out of history
setopt hist_reduce_blanks
setopt hist_verify               # expand !! but let me see it before running
setopt hist_expire_dups_first

##### COMPLETION ###############################################################

# Custom functions and completions. The (N-.) qualifier follows symlinks, which
# matters because Stow gives us symlinks rather than regular files.
() {
  local fndir=${XDG_CONFIG_HOME:-$HOME/.config}/zsh/functions
  if [[ -d $fndir ]]; then
    fpath=($fndir $fpath)
    autoload -Uz $fndir/*(N-.:t)
  fi
}

autoload -Uz compinit
() {
  local dump=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump
  [[ -d ${dump:h} ]] || mkdir -p ${dump:h}
  # Only pay for the security check once a day; -C skips it otherwise.
  if [[ -n ${dump}(#qN.mh-24) ]]; then
    compinit -C -d $dump
  else
    compinit -d $dump
    # Compile the dump in the background; it makes the next start faster.
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
#
# Loaded before the plugins on purpose: prompt_enable_transient installs an
# accept-line widget, and zsh-abbr / fast-syntax-highlighting must wrap it
# rather than the other way round.

source ${XDG_CONFIG_HOME:-$HOME/.config}/zsh/prompt.zsh
[[ -f ${XDG_CONFIG_HOME:-$HOME/.config}/zsh/prompt.google.zsh ]] &&
  source ${XDG_CONFIG_HOME:-$HOME/.config}/zsh/prompt.google.zsh
[[ -f ${XDG_CONFIG_HOME:-$HOME/.config}/zsh/prompt.local.zsh ]] &&
  source ${XDG_CONFIG_HOME:-$HOME/.config}/zsh/prompt.local.zsh
prompt_enable_transient

##### PLUGINS ##################################################################

if [[ ! -d ~/.antidote ]]; then
  git clone --depth=1 https://github.com/mattmc3/antidote.git ~/.antidote
fi

ABBR_SET_EXPANSION_CURSOR=1

# zsh-abbr persists abbreviations by writing a temp file and rename(2)-ing it
# over its storage file. rename(2) replaces the path, so if that path is a
# symlink the symlink is destroyed and the dotfiles repo silently stops
# receiving updates. Point zsh-abbr straight at the file inside the checkout
# instead, so there is no symlink in the way and `abbr add` shows up in
# `git status`.
#
# %x is the file currently being sourced (this .zshrc) and :A resolves it
# through the symlink, giving the checkout's zsh/ directory. If .zshrc is a
# real file in $HOME rather than a symlink this resolves to zsh-abbr's own
# default path, so the override is a harmless no-op.
() {
  local abbr_file=${${(%):-%x}:A:h}/.config/zsh-abbr/user-abbreviations
  [[ -f $abbr_file ]] && export ABBR_USER_ABBREVIATIONS_FILE=$abbr_file
}

source ~/.antidote/antidote.zsh
antidote load

##### KEYBINDS #################################################################
# (The emacs keymap itself is selected near the top, before plugins load.)

# History search on the current prefix.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search;   bindkey '^P' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search; bindkey '^N' down-line-or-beginning-search

# Word-wise movement and deletion.
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[^?'    backward-kill-word
bindkey '^[[3~'   delete-char
bindkey '^[[H'    beginning-of-line
bindkey '^[[F'    end-of-line

# C-x C-e: edit the current command line in $EDITOR.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# C-x y: copy the current command line to the clipboard.
copy-buffer-to-clipboard() { print -rn -- $BUFFER | clip }
zle -N copy-buffer-to-clipboard
bindkey '^Xy' copy-buffer-to-clipboard

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

if [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
  source /usr/share/doc/fzf/examples/completion.zsh
fi
(( $+commands[fzf] ))    && source <(fzf --zsh)
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
(( $+commands[mise] ))   && eval "$(mise activate zsh)"

##### ALIASES ##################################################################

[[ -f ~/.aliases ]] && source ~/.aliases
