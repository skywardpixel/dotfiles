# vi: ft=zsh
#
# A small, dependency-free zsh prompt.
#
#   * no framework, no external prompt binary, ~1ms of startup cost
#   * VCS status (git / hg / jj) is computed by a background job and painted in
#     when ready, so a slow or network-backed checkout never blocks the prompt
#   * results are cached per repo root and only recomputed when the repo's
#     state files actually change, so the steady state costs zero forks
#
# Layout:
#
#   prompt.zsh            this file: appearance, directory, async engine, hooks
#   prompt/vcs.zsh        VCS framework: discovery, caching, backend registry
#   prompt/vcs-git.zsh    one self-contained module per backend
#   prompt/vcs-hg.zsh
#   prompt/vcs-jj.zsh
#
# Everything below prompt.zsh is optional. With no VCS modules loaded the prompt
# still works; it just never shows a VCS segment. See prompt/vcs.zsh for the
# contract a backend module implements.
#
# This file is deliberately generic: it knows nothing about any particular
# hosting environment. Site-specific behaviour is added by defining the hooks
# below in a separate file sourced afterwards.
#
# Hooks -- each sets REPLY (or `reply`) and returns zero, or returns non-zero to
# decline. They use REPLY rather than stdout so the prompt never forks to call
# them.
#
#   prompt_dir_segment           REPLY = replacement for the directory segment
#   prompt_vcs_root_hint         REPLY = "<type> <root>", skips the upward scan
#   prompt_vcs_watch_extra R T   reply = extra files whose mtime invalidates the
#                                cache for repo root R of type T
#   prompt_hg_extra R            REPLY = extra text for the hg segment; may read
#                                $_pr_hg_extra (see PROMPT_HG_EXTRA_TEMPLATE)
#   prompt_jj_extra R            REPLY = extra text for the jj segment
#
# The last two run inside the background job, so they may call commands.
#
# Everything here is plain zsh. To change how it looks, edit the two arrays
# below; there is no configuration wizard and no generated file.

setopt prompt_subst
autoload -Uz add-zsh-hook
zmodload zsh/datetime

##### APPEARANCE ###############################################################
#
# Shared keys only. A backend module contributes its own colour and glyphs (the
# git icon, the ahead/behind arrows, ...) so that removing the module removes
# every trace of it.

# 256-colour indices, or '#rrggbb' on a truecolor terminal.
typeset -gA PROMPT_COLOR=(
  dir        31    # directory, leading components
  dir_bold   39    # directory, last component
  ok        108    # prompt character after a successful command
  dirty     215    # uncommitted changes
  conflict  203
  error     203    # non-zero exit status
  duration  101
  meta      244    # de-emphasised (descriptions, counts)
)

typeset -gA PROMPT_GLYPH=(
  dirty    '*'
  conflict '~'
  char     $'\u276f'   # ❯
)

# Trim commit descriptions to this many characters (0 disables them).
typeset -g PROMPT_DESC_WIDTH=40

# Show only the prompt character once a command has been accepted.
typeset -g PROMPT_TRANSIENT=1

##### SMALL HELPERS ############################################################

# Escape '%' so repo/directory names can never be read as prompt escapes.
_pr_esc() { REPLY=${1//\%/%%} }

_pr_trim() { if (( $#1 > $2 )); then REPLY="${1[1,$2]}…"; else REPLY=$1; fi }

# Append coloured text to the caller's $_out. A function call rather than a
# command substitution, so rendering a segment costs zero forks.
_pr_add() { _out+="%F{${PROMPT_COLOR[$1]}}${2}%f" }

##### MODULES ##################################################################
#
# Set either of these before sourcing this file to override.
#
# PROMPT_VCS_MODULES is the *detection order*, not just a list: the first
# backend whose root test matches wins. jj must come before git, because a
# colocated jj repo contains both .jj and .git and the jj segment is the useful
# one. Drop a name to stop paying for it entirely.

typeset -g PROMPT_MODULE_DIR=${PROMPT_MODULE_DIR:-${${(%):-%x}:A:h}/prompt}
(( $+PROMPT_VCS_MODULES )) || typeset -ga PROMPT_VCS_MODULES=( jj hg git )

if [[ -r $PROMPT_MODULE_DIR/vcs.zsh ]]; then
  source $PROMPT_MODULE_DIR/vcs.zsh
  for _pr_module in $PROMPT_VCS_MODULES; do
    [[ -r $PROMPT_MODULE_DIR/vcs-$_pr_module.zsh ]] &&
      source $PROMPT_MODULE_DIR/vcs-$_pr_module.zsh
  done
  unset _pr_module
fi

##### DIRECTORY ################################################################

# Sets REPLY to the rendered directory segment. Uses REPLY rather than stdout
# because a command substitution here would fork on every prompt.
_pr_dir() {
  if (( $+functions[prompt_dir_segment] )); then
    REPLY=''
    prompt_dir_segment && [[ -n $REPLY ]] && return 0
  fi

  _pr_esc "${(D)PWD}"                       # (D) => $HOME becomes ~
  local p=$REPLY head=${REPLY%/*} tail=${REPLY##*/}
  if [[ $p == $tail || $p == '/' ]]; then
    REPLY="%B%F{${PROMPT_COLOR[dir_bold]}}${p}%f%b"
  else
    REPLY="%F{${PROMPT_COLOR[dir]}}${head}/%f%B%F{${PROMPT_COLOR[dir_bold]}}${tail}%f%b"
  fi
}

##### ASYNC ENGINE #############################################################
#
# At most one background job at a time. The child writes "<serial>\n<segment>"
# into a pipe; `zle -F` wakes us when it is readable and we repaint in place.

typeset -g  _pr_fd=0
typeset -gi _pr_pid=0
typeset -gi _pr_serial=0
typeset -gA _pr_cache=()      # repo root -> rendered segment
typeset -gA _pr_sig=()        # repo root -> signature the segment was built from
typeset -g  PROMPT_VCS=''

_pr_async_stop() {
  if [[ $_pr_fd != 0 ]]; then
    zle -F $_pr_fd 2>/dev/null
    exec {_pr_fd}<&- 2>/dev/null
    _pr_fd=0
  fi
  (( _pr_pid )) && { kill -TERM $_pr_pid 2>/dev/null; _pr_pid=0 }
}

_pr_async_start() {
  _pr_async_stop
  (( _pr_serial++ ))
  local serial=$_pr_serial type=$_pr_type root=$_pr_root

  exec {_pr_fd}< <(
    print -r -- $serial
    builtin cd -q -- $root 2>/dev/null || exit
    _pr_vcs_${type}_render $root
  )
  _pr_pid=$!
  command true                # make sure zsh has wired up the fd
  zle -F $_pr_fd _pr_async_done
}

_pr_async_done() {
  local fd=$1 out=''
  zle -F $fd
  IFS='' read -r -u $fd -d '' out
  exec {fd}<&- 2>/dev/null
  _pr_fd=0 _pr_pid=0

  local serial=${out%%$'\n'*}
  (( serial == _pr_serial )) || return 0        # stale; we have moved on

  local segment=${out#*$'\n'}
  segment=${segment%$'\n'}
  _pr_cache[$_pr_root]=$segment
  _pr_sig[$_pr_root]=$_pr_pending_sig

  [[ $segment == $PROMPT_VCS ]] && return 0
  PROMPT_VCS=$segment
  zle reset-prompt
}

##### HOOKS ####################################################################

typeset -gF _pr_started=0
typeset -g  _pr_duration='' _pr_dirseg='' _pr_pending_sig=''

_pr_preexec() { _pr_started=$EPOCHREALTIME }

_pr_fmt_duration() {
  local -F elapsed=$1
  local -i s=$(( elapsed ))
  if   (( s >= 3600 )); then REPLY="$(( s / 3600 ))h$(( (s % 3600) / 60 ))m"
  elif (( s >= 60   )); then REPLY="$(( s / 60 ))m$(( s % 60 ))s"
  else                       REPLY="$(printf '%.1f' $elapsed)s"
  fi
}

_pr_precmd() {
  local -i last_status=$?

  local REPLY

  _pr_duration=''
  if (( _pr_started )); then
    local -F elapsed=$(( EPOCHREALTIME - _pr_started ))
    if (( elapsed > 2 )); then
      _pr_fmt_duration $elapsed; _pr_duration=$REPLY
    fi
    _pr_started=0
  fi

  _pr_dir; _pr_dirseg=$REPLY

  # _pr_detect only exists when prompt/vcs.zsh is loaded.
  if (( $+functions[_pr_detect] )) && _pr_detect; then
    _pr_signature $_pr_root $_pr_type
    _pr_pending_sig=$REPLY
    if [[ -n $_pr_pending_sig && ${_pr_sig[$_pr_root]-} == $_pr_pending_sig ]]; then
      # Nothing the backend reports can have changed: reuse the cache, no fork.
      _pr_async_stop
      PROMPT_VCS=${_pr_cache[$_pr_root]}
    else
      # Show the last known value straight away, then refresh in the background.
      PROMPT_VCS=${_pr_cache[$_pr_root]-}
      _pr_async_start
    fi
  else
    _pr_async_stop
    PROMPT_VCS=''
  fi

  _pr_build $last_status
}

_pr_build() {
  local -i last_status=$1

  PROMPT='${_pr_dirseg}${PROMPT_VCS:+ ${PROMPT_VCS}}'$'\n'
  if (( last_status )); then
    PROMPT+="%F{${PROMPT_COLOR[error]}}${PROMPT_GLYPH[char]}%f "
  else
    PROMPT+="%F{${PROMPT_COLOR[ok]}}${PROMPT_GLYPH[char]}%f "
  fi

  local -a right
  (( last_status ))       && right+=( "%F{${PROMPT_COLOR[error]}}${last_status}%f" )
  [[ -n $_pr_duration ]]  && right+=( "%F{${PROMPT_COLOR[duration]}}${_pr_duration}%f" )
  right+=( "%(1j.%F{${PROMPT_COLOR[meta]}}⚙%j%f.)" )
  RPROMPT=${(j: :)right}
}

add-zsh-hook precmd  _pr_precmd
add-zsh-hook preexec _pr_preexec

##### TRANSIENT PROMPT (optional) ##############################################
#
# Collapse an accepted command line to a bare prompt character so scrollback
# stays readable.
#
# Call this *before* loading plugins that wrap accept-line (zsh-abbr,
# fast-syntax-highlighting). They will then wrap our widget, which puts us last
# in the chain -- right before the line is accepted, and after abbreviations
# have expanded. Chaining the other way round does not work: fast-syntax-
# highlighting binds its wrapper to a generated name that cannot be re-invoked.

prompt_enable_transient() {
  (( PROMPT_TRANSIENT )) || return 0
  [[ ${widgets[accept-line]} == 'user:_pr_accept_line' ]] && return 0

  _pr_accept_line() {
    PROMPT="%F{${PROMPT_COLOR[meta]}}${PROMPT_GLYPH[char]}%f "
    RPROMPT=''
    zle .reset-prompt
    zle .accept-line
  }
  zle -N accept-line _pr_accept_line
}
