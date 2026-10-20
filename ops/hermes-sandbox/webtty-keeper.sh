#!/usr/bin/env bash
# Watchdog for the sandbox web terminal, run by the Hermes cron scheduler
# (the gateway) every few minutes. Silent unless it actually had to repair
# something, so `--no-agent` delivery stays quiet.
set -u

WT="$HOME/.hermes/webtty"
export PATH="$HOME/.local/bin:$PATH"

pid_alive() { [ -f "$1" ] && kill -0 "$(cat "$1" 2>/dev/null)" 2>/dev/null; }
running() { pgrep -f "$1" >/dev/null 2>&1; }

problems=()
pid_alive "$WT/supervisor.pid" || problems+=("supervisor down")
running "[w]ebtty/bin/ttyd" || problems+=("ttyd down")
running "[b]in/cloudflared tunnel" || problems+=("tunnel down")

# The tunnel can outlive its connector; a 5xx/530 on the public URL means dead.
url="$(cat "$WT/public-url.txt" 2>/dev/null || true)"
if [ -z "$url" ]; then
    problems+=("no public url")
else
    code="$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$url/" 2>/dev/null || echo 000)"
    case "$code" in
        401|200) ;;
        *) problems+=("public url returns $code") ;;
    esac
fi

[ ${#problems[@]} -eq 0 ] && exit 0

"$HOME/.local/bin/webtty" start >/dev/null 2>&1 || true
sleep 10
printf 'webtty watchdog: restarted after %s -> %s\n' \
    "$(IFS=,; echo "${problems[*]}")" \
    "$(cat "$WT/public-url.txt" 2>/dev/null || echo 'no url yet')"
