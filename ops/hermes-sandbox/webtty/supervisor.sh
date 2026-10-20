#!/usr/bin/env bash
# Keep the web terminal reachable: ttyd on loopback plus a Cloudflare quick
# tunnel for the public URL. No systemd in this sandbox, so this loop is the
# service manager. `webtty stop` drops .stop to end it.
set -u

WT="$HOME/.hermes/webtty"
LOG="$HOME/.hermes/logs"
STOP="$WT/.stop"
SUP_LOG="$LOG/webtty-supervisor.log"

export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
mkdir -p "$LOG"
rm -f "$STOP"
echo $$ > "$WT/supervisor.pid"

port="$(sed -n 's/^port=//p' "$WT/credentials" 2>/dev/null)"
port="${port:-7681}"

log() { printf '%s %s\n' "$(date -Is)" "$*" >> "$SUP_LOG"; }

ttyd_loop() {
    while [ ! -f "$STOP" ]; do
        log "starting ttyd on 127.0.0.1:$port"
        "$WT/run-ttyd.sh" >> "$LOG/ttyd.log" 2>&1
        log "ttyd exited code=$?"
        [ -f "$STOP" ] && break
        sleep 3
    done
}

tunnel_loop() {
    while [ ! -f "$STOP" ]; do
        rm -f "$WT/public-url.txt"
        # Start each run with an empty log so the URL we parse is this run's,
        # never the previous tunnel's.
        : > "$LOG/cloudflared.log"
        "$WT/bin/cloudflared" tunnel --url "http://127.0.0.1:$port" \
            --no-autoupdate --logfile "$LOG/cloudflared.log" --loglevel info \
            >> "$LOG/cloudflared-stdio.log" 2>&1 &
        cf=$!
        log "cloudflared started pid=$cf"
        for _ in $(seq 1 120); do
            url="$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$LOG/cloudflared.log" 2>/dev/null | tail -1)"
            if [ -n "$url" ]; then
                printf '%s\n' "$url" > "$WT/public-url.txt"
                log "public url: $url"
                break
            fi
            kill -0 "$cf" 2>/dev/null || break
            sleep 1
        done
        wait "$cf"
        log "cloudflared exited code=$?"
        [ -f "$STOP" ] && break
        sleep 5
    done
}

ttyd_loop &
tunnel_loop &
wait
log "supervisor exit"
rm -f "$WT/supervisor.pid"
