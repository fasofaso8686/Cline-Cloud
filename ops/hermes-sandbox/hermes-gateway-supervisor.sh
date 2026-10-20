#!/usr/bin/env bash
# Keep `hermes gateway run` alive in a sandbox without systemd/cron.
# Restart-on-exit loop; `hermes-svc stop` drops the .stop flag to end the loop.
set -u

SVC_DIR="$HOME/.hermes/svc"
LOG_DIR="$HOME/.hermes/logs"
STOP_FLAG="$SVC_DIR/.stop"
SUP_LOG="$LOG_DIR/supervisor.log"

export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"

mkdir -p "$LOG_DIR"
rm -f "$STOP_FLAG"
echo $$ > "$SVC_DIR/supervisor.pid"

log() { printf '%s %s\n' "$(date -Is)" "$*" >> "$SUP_LOG"; }

log "supervisor start pid=$$"
while [ ! -f "$STOP_FLAG" ]; do
    log "launching: hermes gateway run"
    "$HOME/.local/bin/hermes" gateway run >> "$LOG_DIR/gateway.log" 2>&1
    code=$?
    log "gateway exited code=$code"
    [ -f "$STOP_FLAG" ] && break
    sleep 5
done
log "supervisor exit"
rm -f "$SVC_DIR/supervisor.pid"
