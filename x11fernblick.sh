#!/usr/bin/env bash

set -e

VNCPASSWD=vncpasswd
VNCVIEWER=vncviewer
SS=ss

find_free_port() {
  local LOWER_PORT
  local UPPER_PORT
  read LOWER_PORT UPPER_PORT < /proc/sys/net/ipv4/ip_local_port_range

  local port=$(shuf -i ${LOWER_PORT}-${UPPER_PORT} -n 1)
  while "$SS" -lpn | grep -q ":$port "; do
    port=$(shuf -i ${LOWER_PORT}-${UPPER_PORT} -n 1)
  done
  echo $port
}

wait_for_port() {
  while ! "$SS" -nlt | grep -q ":$1 "; do
    echo "waiting for port $1"
    sleep 1
  done
}

HELP_MSG="Usage: $0 USER@HOSTNAME [DISPLAY]

Connect to a remote X11 server and show its desktop locally.

  USER@HOSTNAME   A ssh destination to connect to
  DISPLAY         Display to connect to (default :0)

Options
  -h, --help      Display this help"

unset REMOTEHOST
REMOTEDISPLAY=":0"

REST=()
while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    -h|--help)
      echo "$HELP_MSG"
      exit 0
      ;;
    *)
      REST+=("$key")
      ;;
  esac

  shift
done

if [[ ${#REST[@]} -eq 0 ]]; then
  echo "$HELP_MSG"
  exit 0
elif [[ ${#REST[@]} -gt 2 ]]; then
  echo "error: Too many arguments provided."
  exit 1
fi

if [[ ${#REST[@]} -ge 1 ]]; then
  REMOTEHOST="${REST[0]}"
fi

if [[ ${#REST[@]} -ge 2 ]]; then
  REMOTEDISPLAY="${REST[1]}"
fi

LOCALPORT=$(find_free_port)
REMOTEPORT="${LOCALPORT}"
VNCPASSWDFILE=$(mktemp)

# generate random password
VNCPASSWD_PASSWORD="$(tr -dc A-Za-z0-9 </dev/urandom | head -c12 | "${VNCPASSWD}" -f)"
echo -n "${VNCPASSWD_PASSWORD}" > "${VNCPASSWDFILE}"
VNCPASSWD_PASSWORD_BASE32="$(echo -n "${VNCPASSWD_PASSWORD}" | base32)"

echo "Connecting to display ${REMOTEDISPLAY} on ${REMOTEHOST} via port ${LOCALPORT}..."

ssh -L "${LOCALPORT}:localhost:${REMOTEPORT}" ${REMOTEHOST} \
    "VNCPASSWDFILE=\$(mktemp);
    echo -n \"${VNCPASSWD_PASSWORD_BASE32}\" | base32 -d > \${VNCPASSWDFILE};
    x11vnc -localhost \
            -display ${REMOTEDISPLAY} \
            -ncache_cr \
            -noxdamage \
            -nowf -noscr \
            -rfbport ${REMOTEPORT} \
            -rfbauth \"\${VNCPASSWDFILE}\";
    rm -v \"\${VNCPASSWDFILE}\"" &
SSHPID=$!

wait_for_port "${LOCALPORT}"

"$VNCVIEWER" \
    -passwd "${VNCPASSWDFILE}" \
    localhost:"${LOCALPORT}"

wait $SSHPID

rm -v "${VNCPASSWDFILE}"

# EOF #
