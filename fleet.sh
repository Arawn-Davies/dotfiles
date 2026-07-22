################################################################################
# Server Fleet SSH
#
# Single-command SSH access to the home server fleet. All hosts start out on
# the same root password until `fleet:setup` copies your public key to each
# one, after which `fleet <host>` is passwordless (regular pubkey auth).
#
# The real password does NOT belong in this file (it's tracked in git). Set
# it in ~/.zshrc.local instead, e.g.:
#   export FLEET_PASSWORD='the-real-password'
# It only needs to be correct until fleet:setup has run once per host.
#
# Usage:
#   fleet:setup        Copy your SSH key to every fleet host (run once, or
#                       again after a password reset / new box)
#   fleet <name|ip>     SSH in, e.g. `fleet 1` or `fleet 10.0.0.10`
#   fleet               List fleet hosts
################################################################################

typeset -gA FLEET_HOSTS=(
  1 10.0.0.10
  2 10.0.0.20
  3 10.0.0.50
  4 10.0.0.80
)

FLEET_USER=root
: ${FLEET_PASSWORD:=changeme}

function fleet() {
  if [[ -z "$1" ]]; then
    echo "Fleet hosts:"
    local name
    for name in "${(@ok)FLEET_HOSTS}"; do
      echo "  $name -> $FLEET_HOSTS[$name]"
    done
    return 0
  fi

  local target="${FLEET_HOSTS[$1]:-$1}"
  ssh "${FLEET_USER}@${target}"
}

function fleet:setup() {
  if ! command -v ssh-copy-id >/dev/null; then
    echo "Error: ssh-copy-id not found."
    return 1
  fi

  local have_sshpass=0
  if command -v sshpass >/dev/null; then
    have_sshpass=1
  else
    echo "sshpass not installed — you'll be prompted for the password once per host."
    echo "(install sshpass to copy keys to all hosts unattended)"
  fi

  local name ip
  for name in "${(@ok)FLEET_HOSTS}"; do
    ip="$FLEET_HOSTS[$name]"
    echo "==> $ip"
    if [[ $have_sshpass -eq 1 ]]; then
      sshpass -p "$FLEET_PASSWORD" ssh-copy-id -o StrictHostKeyChecking=accept-new "${FLEET_USER}@${ip}"
    else
      ssh-copy-id -o StrictHostKeyChecking=accept-new "${FLEET_USER}@${ip}"
    fi
  done
}
