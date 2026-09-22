# vi: ft=zsh
#
# Mercurial backend for prompt.zsh.

# `chg` is Mercurial's command server client: ~0.12s vs ~0.43s for plain `hg`.
# Set PROMPT_HG_CMD before loading to override.
typeset -g PROMPT_HG_CMD=${PROMPT_HG_CMD:-${commands[chg]:-${commands[hg]:-}}}
[[ -n $PROMPT_HG_CMD ]] || return 0    # unusable: stay unregistered

PROMPT_COLOR+=(
  hg 180
)

PROMPT_GLYPH+=(
  hg $'\uf223'   #  mercurial
)

# Extra Mercurial template keywords appended to the log query, e.g.
# $'\x1f{mykeyword}'. Values land in $_pr_hg_extra for prompt_hg_extra to
# render, which keeps a site extension from costing a second hg invocation.
typeset -g PROMPT_HG_EXTRA_TEMPLATE=''

_pr_vcs_hg_root()  { [[ -d $1/.hg ]] }

_pr_vcs_hg_watch() { reply=( $1/.hg/dirstate ) }

_pr_vcs_hg_render() {
  local root=$1

  # One invocation for the commit facts. An overlay can append its own template
  # keywords via PROMPT_HG_EXTRA_TEMPLATE; their values arrive in $_pr_hg_extra
  # and are rendered by prompt_hg_extra, so no second hg call is needed.
  local tpl='{rev}\x1f{branch}\x1f{desc|firstline}'
  tpl+=$PROMPT_HG_EXTRA_TEMPLATE
  local raw="$(_pr_run $PROMPT_HG_CMD log --rev . --template "$tpl")"
  [[ -n $raw ]] || return 1
  local -a f; f=( "${(@ps.$_PR_FS.)raw}" )
  local rev=$f[1] branch=$f[2] desc=$f[3]
  local -a _pr_hg_extra; _pr_hg_extra=( "${(@)f[4,-1]}" )

  # ...and one for the dirty flag. Mercurial cannot report both at once.
  local dirty=''
  [[ -n "$(_pr_run $PROMPT_HG_CMD status --modified --added --removed --deleted)" ]] && dirty=1

  local _out='' REPLY
  local label=$rev
  [[ -n $branch && $branch != default ]] && label="${branch}:${rev}"
  _pr_esc "$label"
  _pr_add hg "${PROMPT_GLYPH[hg]} ${REPLY}"

  if (( $+functions[prompt_hg_extra] )); then
    local saved=$REPLY; REPLY=''
    prompt_hg_extra $root && [[ -n $REPLY ]] && _out+=" $REPLY"
    REPLY=$saved
  fi

  [[ -n $dirty ]] && _pr_add dirty " ${PROMPT_GLYPH[dirty]}"

  if (( PROMPT_DESC_WIDTH > 0 )) && [[ -n $desc ]]; then
    _pr_trim "$desc" $PROMPT_DESC_WIDTH; _pr_esc "$REPLY"
    _pr_add meta " ${REPLY}"
  fi
  print -rn -- "$_out"
}

_pr_vcs_register hg
