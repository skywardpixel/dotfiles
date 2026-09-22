# vi: ft=zsh
#
# VCS framework for prompt.zsh.
#
# This file knows *how* to find a repository and when to re-query it, but
# nothing about any particular version control system. Each backend lives in its
# own prompt/vcs-<name>.zsh and registers itself here.
#
# Loading this file is optional: without it the prompt simply shows no VCS
# segment.
#
# ---------------------------------------------------------------------------
# Backend contract
#
# A backend named <name> defines:
#
#   _pr_vcs_<name>_root DIR      return 0 if DIR is a repository root of this
#                                type. Called once per directory per level of
#                                the upward scan, so keep it to a file test.
#
#   _pr_vcs_<name>_render ROOT   print one finished, coloured segment, or return
#                                non-zero to show nothing. Runs inside the
#                                background job with the cwd set to ROOT, so it
#                                may take as long as it needs to.
#
# and may define:
#
#   _pr_vcs_<name>_watch ROOT    reply = files whose mtimes decide whether the
#                                cached segment is still valid. Omit this (or
#                                return an empty reply) if the backend's answer
#                                can change without any file changing; the
#                                prompt will then re-query on every prompt,
#                                which is only acceptable for fast backends.
#
# Finally it calls `_pr_vcs_register <name>`, which it should skip when the
# backend is unusable (binary not installed) so we never pay to probe for it.
# ---------------------------------------------------------------------------

zmodload zsh/stat

# Hard limit on a background VCS probe. jj's first command of the day can take
# tens of seconds (daemon start + re-auth); we would rather show nothing.
typeset -g PROMPT_VCS_TIMEOUT=10

##### REGISTRY #################################################################

# Detection order. The first backend whose _root test passes at a given
# directory wins, so this is not merely cosmetic: a colocated jj repo contains
# both .jj and .git, and we want the jj segment for it.
typeset -ga _pr_vcs_order=()

_pr_vcs_register() {
  local name=$1
  (( $+functions[_pr_vcs_${name}_root] )) || return 1
  (( $+functions[_pr_vcs_${name}_render] )) || return 1
  _pr_vcs_order+=( $name )
}

##### DISCOVERY -- synchronous, but only a few stat() calls ####################

typeset -g _pr_type='' _pr_root=''

_pr_detect() {
  _pr_type='' _pr_root=''
  (( $#_pr_vcs_order )) || return 1

  # The hook reports through REPLY ("<type> <root>"); a command substitution
  # here would fork on every prompt. An unregistered type is ignored rather
  # than trusted, otherwise we would dispatch to a renderer that is not loaded.
  if (( $+functions[prompt_vcs_root_hint] )); then
    REPLY=''
    if prompt_vcs_root_hint && [[ -n $REPLY ]]; then
      local hinted=${REPLY%% *}
      if (( ${_pr_vcs_order[(Ie)$hinted]} )); then
        _pr_type=$hinted
        _pr_root=${REPLY#* }
        return 0
      fi
    fi
  fi

  local dir=$PWD name
  while :; do
    for name in $_pr_vcs_order; do
      if _pr_vcs_${name}_root $dir; then
        _pr_type=$name _pr_root=$dir
        return 0
      fi
    done
    [[ $dir == / || -z $dir ]] && return 1
    dir=${dir:h}
  done
}

# A cheap fingerprint of "has anything changed since we last looked?".
# Returns the empty string for backends that cannot answer that question, which
# disables the skip-the-refresh optimisation for them.
_pr_signature() {
  local root=$1 type=$2 f
  local -a watch=() st reply

  if (( $+functions[_pr_vcs_${type}_watch] )); then
    reply=()
    _pr_vcs_${type}_watch $root && watch=( $reply )
  fi

  # No base fingerprint means the backend has told us it cannot be cached, so
  # there is nothing for an overlay to extend either.
  (( $#watch )) || { REPLY=''; return 0 }

  # Let a site overlay add its own invalidation files.
  if (( $+functions[prompt_vcs_watch_extra] )); then
    reply=()
    prompt_vcs_watch_extra $root $type && watch+=( $reply )
  fi

  REPLY=''
  for f in $watch; do
    if zstat -A st +mtime -- $f 2>/dev/null; then REPLY+="$st:"; else REPLY+='-:'; fi
  done
}

##### BACKEND SUPPORT ##########################################################

# Run a VCS command with a hard deadline. jj's first command of the day can
# block for tens of seconds (daemon start + re-auth) and jj outages can hang it
# for minutes; we would rather show a stale segment than leak a stuck job.
_pr_run() {
  if (( $+commands[timeout] )); then
    command timeout --signal=TERM $PROMPT_VCS_TIMEOUT "$@" 2>/dev/null
  else
    command "$@" 2>/dev/null
  fi
}

# Field separator used to pack VCS data into one line. Verified to survive both
# jj and Mercurial template escaping.
typeset -g _PR_FS=$'\x1f'
