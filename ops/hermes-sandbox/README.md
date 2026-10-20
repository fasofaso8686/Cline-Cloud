# Hermes Agent in this sandbox

Hermes Agent (NousResearch/hermes-agent) is installed from
`https://hermes-agent.nousresearch.com/install.sh` and kept running by a local
supervisor, because this container has neither systemd nor cron.

| Item | Location |
| --- | --- |
| Checkout (stable v0.22.2) | `~/.hermes/hermes-agent` |
| Command | `~/.local/bin/hermes` |
| Tool store / pinned binaries | `~/.hermes/tools` |
| Gateway + cron scheduler log | `~/.hermes/logs/gateway.log` |
| Supervisor log | `~/.hermes/logs/supervisor.log` |

## Running it

```bash
hermes-svc status          # supervisor + gateway PIDs
hermes-svc start|stop|restart
hermes-svc logs 100        # tail the gateway log
hermes gateway status      # Hermes' own view (reports "running manually")
```

`~/.local/bin/hermes-svc` is a symlink to `~/.hermes/svc/hermes-svc`. The
supervisor restarts `hermes gateway run` five seconds after any exit, and an
interactive shell start (`~/.bashrc`) brings it back after a container restart.

To talk to the agent you still need a provider credential:
`hermes model` (pick provider / `/login`) or `hermes auth add <provider>`.

## Sandbox TLS workarounds

The egress proxy re-signs TLS with a local CA (`CN=cline-mitm-ca`, in
`/etc/mitm/ca.crt`) that carries only `basicConstraints=CA:TRUE`.

- **uv (rustls)** rejects the chain outright and has no usable CA flag here
  (0.12.3 ignores `--cert`), so `UV_INSECURE_HOST` scopes a verification opt-out
  to `pypi.org` / `files.pythonhosted.org` only. Exported from `~/.bashrc`; also
  written to `~/.config/uv/uv.toml`, which the installer's `UV_NO_CONFIG=1`
  skips. Python downloads from astral-sh are served from a local
  `UV_PYTHON_INSTALL_MIRROR=file://~/.hermes/mirror/pbs` when needed.
- **Python 3.13+** enables `ssl.VERIFY_X509_STRICT`, which rejects a CA without
  `keyUsage`. `sitecustomize.py` clears that one flag (chain and hostname
  verification stay on) and is installed into the pinned interpreter's
  `site-packages` plus the uv-managed interpreters.
- **pm's downloader** uses urllib, so the same strict check broke binary
  fetches; `seed-pm-artifacts.py` pre-downloads every lock-pinned artifact with
  curl, verifies its sha256, and publishes it into `~/.hermes/tools/fetch-<sha>/`
  so pm skips the download. Run it before `hermes update`.

Reverting: delete the `sitecustomize.py` copies and the `UV_INSECURE_HOST`
export.
