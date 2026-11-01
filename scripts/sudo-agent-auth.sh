#!/usr/bin/env bash
# Let sudo on this server authenticate through a forwarded SSH agent, so a
# Secure Enclave key on a Mac answers sudo with Touch ID. Password sudo stays
# as the fallback. See "Touch ID for SSH and sudo" in README.md.
#
# Changes system files, so it is run by hand on personal Debian/Ubuntu servers
# and is never called by `make`. Safe to run again, e.g. to add a second key.
#
# Usage: sudo ./scripts/sudo-agent-auth.sh <public-key-file>
set -euo pipefail

KEY_FILE="${1:?usage: $0 <public-key-file>}"
KEYS=/etc/security/sudo_authorized_keys
SUDOERS=/etc/sudoers.d/ssh-agent-auth
PAM=/etc/pam.d/sudo
PAM_LINE="auth sufficient pam_ssh_agent_auth.so file=$KEYS"

die() { echo "error: $*" >&2; exit 1; }

# The overlay only exists on work checkouts, whose servers are not ours to change.
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ ! -e "$repo/google.mk" ]] || die "work checkout (google.mk found); refusing to run"

[[ $EUID -eq 0 ]] || die "run as root"
command -v apt-get >/dev/null || die "only apt systems are supported"
ssh-keygen -lf "$KEY_FILE" >/dev/null || die "$KEY_FILE is not a public key"
[[ $(grep -c . "$KEY_FILE") -eq 1 ]] || die "$KEY_FILE must hold exactly one key"
grep -qE '^@include[[:space:]]+common-auth' "$PAM" || die "no '@include common-auth' in $PAM"

apt-get install -y libpam-ssh-agent-auth

# Root-owned on purpose: a key list the user can write gives any process
# running as that user a path to root.
touch "$KEYS"
chown root:root "$KEYS"
chmod 644 "$KEYS"
key="$(grep . "$KEY_FILE")"
grep -qxF "$key" "$KEYS" || printf '%s\n' "$key" >>"$KEYS"

# Validate before install: a broken sudoers file disables sudo completely.
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
echo 'Defaults env_keep += "SSH_AUTH_SOCK"' >"$tmp"
visudo -cf "$tmp" >/dev/null
install -o root -g root -m 440 "$tmp" "$SUDOERS"

if ! grep -qxF "$PAM_LINE" "$PAM"; then
  [[ -e "$PAM.pre-agent-auth" ]] || cp -p "$PAM" "$PAM.pre-agent-auth"
  sed -i "/^@include[[:space:]]\+common-auth/i $PAM_LINE" "$PAM"
fi

echo "Done. Test from a new forwarded SSH session: sudo -k && sudo true"
echo "Undo: restore $PAM.pre-agent-auth, then remove $SUDOERS and $KEYS"
