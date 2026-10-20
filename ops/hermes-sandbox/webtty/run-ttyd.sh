#!/usr/bin/env bash
# ttyd front-end for the sandbox. Bound to loopback: the SSH reverse tunnel is
# the only way in, so the shell is never exposed directly.
set -u

WT="$HOME/.hermes/webtty"
CRED="$WT/credentials"
[ -f "$CRED" ] || { echo "missing $CRED" >&2; exit 1; }

user="$(sed -n 's/^username=//p' "$CRED")"
pass="$(sed -n 's/^password=//p' "$CRED")"
port="$(sed -n 's/^port=//p' "$CRED")"
port="${port:-7681}"

export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
export LANG="${LANG:-C.UTF-8}"

exec "$WT/bin/ttyd.x86_64" \
    --port "$port" --interface 127.0.0.1 \
    --credential "$user:$pass" \
    --writable \
    --max-clients 4 \
    --terminal-type xterm-256color \
    -t titleFixed="Hermes sandbox" \
    -- bash -l
