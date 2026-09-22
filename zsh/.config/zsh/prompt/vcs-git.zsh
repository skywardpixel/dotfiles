# vi: ft=zsh
#
# Git backend for prompt.zsh.

(( $+commands[git] )) || return 0      # unusable: stay unregistered

PROMPT_COLOR+=(
  git 108
)

PROMPT_GLYPH+=(
  git      $'\uf418'   #  git
  staged   '+'
  untrack  '?'
  ahead    $'\u2191'   # ↑
  behind   $'\u2193'   # ↓
)

# -e, not -d: .git is a regular file in worktrees and submodules.
_pr_vcs_git_root() { [[ -e $1/.git ]] }

# Deliberately no _watch function. Editing a tracked file does not touch
# anything under .git, so there is no set of files whose mtimes would tell us
# the answer is unchanged. git status on a local disk is ~5ms, so we simply
# re-query every time rather than risk showing a stale segment.

_pr_vcs_git_render() {
  local line branch='' ab=''
  local -i staged=0 unstaged=0 untracked=0 conflicts=0 ahead=0 behind=0
  local -a lines
  lines=( ${(f)"$(_pr_run git --no-optional-locks status --porcelain=v2 \
                    --branch --untracked-files=normal)"} )
  (( $#lines )) || return 1

  for line in $lines; do
    case $line in
      ('# branch.head '*) branch=${line#\# branch.head } ;;
      ('# branch.ab '*)
        ab=${line#\# branch.ab }
        ahead=${${ab%% *}#+}
        behind=${${ab##* }#-}
        ;;
      ([12]' '*)
        [[ ${line[3]} != '.' ]] && (( staged++ ))
        [[ ${line[4]} != '.' ]] && (( unstaged++ ))
        ;;
      ('u '*) (( conflicts++ )) ;;
      ('? '*) (( untracked++ )) ;;
    esac
  done

  [[ $branch == '(detached)' ]] &&
    branch="@$(_pr_run git rev-parse --short HEAD)"

  local _out='' REPLY
  _pr_esc "$branch"
  local body="${PROMPT_GLYPH[git]} ${REPLY}"
  (( ahead ))  && body+=" ${PROMPT_GLYPH[ahead]}${ahead}"
  (( behind )) && body+=" ${PROMPT_GLYPH[behind]}${behind}"
  _pr_add git "$body"

  (( conflicts )) && _pr_add conflict " ${PROMPT_GLYPH[conflict]}${conflicts}"
  (( staged ))    && _pr_add dirty    " ${PROMPT_GLYPH[staged]}${staged}"
  (( unstaged ))  && _pr_add dirty    " ${PROMPT_GLYPH[dirty]}${unstaged}"
  (( untracked )) && _pr_add meta     " ${PROMPT_GLYPH[untrack]}${untracked}"
  print -rn -- "$_out"
}

_pr_vcs_register git
