#!/usr/bin/env bash

set -e

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

unset REMOTEDISPLAY
unset REMOTEHOST

HELP_MSG="Usage: $0 USER@HOSTNAME [DISPLAY]
Connect to a X11 server at HOSTNAME on DISPLAY (default :0)."

while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    -h|--help)
      echo "$HELP_MSG"
      exit 0
      ;;
    *)
      if [[ -z "${REMOTEHOST+x}" ]]; then
        REMOTEHOST="$key"
      elif [[ -z "${REMOTEDISPLAY+x}" ]]; then
        REMOTEDISPLAY="$key"
      else
        echo "error: Too many arguments provided."
        exit 1
      fi
      ;;
  esac

  shift
done

if [[ -z "$REMOTEHOST" ]]; then
    echo "error: USER@HOSTNAME not provided."
    exit 1
fi

if [[ -z "$REMOTEDISPLAY" ]]; then
    REMOTEDISPLAY=":0"
fi

LOCALPORT=$(find_free_port)
REMOTEPORT="${LOCALPORT}"

echo "Connecting to display ${REMOTEDISPLAY} on ${REMOTEHOST} via port ${LOCALPORT}..."

ssh -L "${LOCALPORT}:localhost:${REMOTEPORT}" ${REMOTEHOST} \
    "x11vnc -localhost \
            -display ${REMOTEDISPLAY} \
            -ncache_cr \
            -noxdamage \
            -nowf -noscr \
            -rfbport ${REMOTEPORT} \
            -rfbauth ~/.vnc/passwd" &
SSHPID=$!

wait_for_port "${LOCALPORT}"

"$VNCVIEWER" \
    -passwd ~/.vnc/passwd \
    localhost:"${LOCALPORT}"

wait $SSHPID

# EOF #
