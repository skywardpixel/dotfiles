# vi: ft=zsh
#
# Jujutsu backend for prompt.zsh.

(( $+commands[jj] )) || return 0       # unusable: stay unregistered

PROMPT_COLOR+=(
  jj 141
)

PROMPT_GLYPH+=(
  jj $'\ueafc'   #  jujutsu
)

_pr_vcs_jj_root() { [[ -d $1/.jj ]] }

# We query jj with --ignore-working-copy, so its answer can only change when one
# of these files does. Skipping the refresh is exact here, not a heuristic.
_pr_vcs_jj_watch() {
  reply=( $1/.jj/working_copy/checkout
          $1/.jj/working_copy/tree_state )
}

_pr_vcs_jj_render() {
  local root=$1

  # --ignore-working-copy is not optional: without it every prompt snapshots the
  # working copy (slow on network-backed checkouts) and takes the repo lock
  # behind your back.
  #
  # Note we concatenate explicit separators rather than using separate(): that
  # helper drops empty arguments, which would silently shift every field.
  local tpl='change_id.shortest(8) ++ "\x1f"
    ++ bookmarks.map(|b| b.name()).join(" ") ++ "\x1f"
    ++ if(conflict, "conflict") ++ "\x1f"
    ++ if(empty, "empty") ++ "\x1f"
    ++ if(divergent, "divergent") ++ "\x1f"
    ++ description.first_line() ++ "\x1f"'
  local raw="$(_pr_run jj log --no-pager --ignore-working-copy --color=never \
      --no-graph --revisions @ --limit 1 --template "$tpl")"
  [[ -n $raw ]] || return 1

  local -a f; f=( "${(@ps.$_PR_FS.)raw}" )
  local change=$f[1] books=$f[2] conflict=$f[3] empty=$f[4] divergent=$f[5] desc=$f[6]

  local _out='' REPLY
  _pr_esc "$change"
  local body="${PROMPT_GLYPH[jj]} ${REPLY}"
  if [[ -n $books ]]; then _pr_esc "$books"; body+=" ${REPLY}"; fi
  _pr_add jj "$body"

  if (( $+functions[prompt_jj_extra] )); then
    REPLY=''
    prompt_jj_extra $root && [[ -n $REPLY ]] && _out+=" $REPLY"
  fi

  [[ -n $conflict  ]] && _pr_add conflict " ${PROMPT_GLYPH[conflict]}"
  [[ -n $divergent ]] && _pr_add conflict " divergent"
  if [[ -n $empty ]]; then
    _pr_add meta " empty"
  else
    _pr_add dirty " ${PROMPT_GLYPH[dirty]}"
  fi

  if (( PROMPT_DESC_WIDTH > 0 )) && [[ -n $desc ]]; then
    _pr_trim "$desc" $PROMPT_DESC_WIDTH; _pr_esc "$REPLY"
    _pr_add meta " ${REPLY}"
  fi
  print -rn -- "$_out"
}

_pr_vcs_register jj
