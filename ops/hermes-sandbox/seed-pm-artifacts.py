"""Pre-seed Hermes pm's fetch cache with lock-pinned artifacts.

pm's downloader uses urllib + OpenSSL 3.5, which rejects the sandbox egress
proxy's CA (CN=cline-mitm-ca lacks a keyUsage extension). curl trusts it via
CURL_CA_BUNDLE, so we fetch the archives here, verify them against pm/lock.json
and publish them into the store the same way pm does (fetch-<sha256>/<file>).
"""

import hashlib
import json
import subprocess
import sys
import urllib.parse
from pathlib import Path

REPO = Path("/home/node/.hermes/hermes-agent")
STORE = Path("/home/node/.hermes/tools")
PLATFORMS = ("linux-x64", "any", "linux-arm64")

WANTED = sys.argv[1:] or ["python", "ffmpeg", "uv", "node", "npm", "ripgrep", "gh", "bws", "agent-browser"]


def artifacts(package):
    entry = package["artifacts"]
    if isinstance(entry, list):
        yield from entry
        return
    for platform in PLATFORMS:
        if platform in entry:
            yield entry[platform]
            return
    if "any" in entry:
        yield entry["any"]


def main() -> int:
    lock = json.loads((REPO / "pm" / "lock.json").read_text())["packages"]
    failures = []
    for name in WANTED:
        if name not in lock:
            continue
        for artifact in artifacts(lock[name]):
            digest, url = artifact["sha256"], artifact["url"]
            name_in_url = Path(urllib.parse.unquote(url.rsplit("/", 1)[-1])).name
            target_dir = STORE / f"fetch-{digest}"
            target = target_dir / name_in_url
            if target.is_file() and hashlib.sha256(target.read_bytes()).hexdigest() == digest:
                print(f"= {name}: cached")
                continue
            # Stage inside the store so publication is a same-filesystem rename.
            tmp = STORE / ".seed-staging" / name_in_url
            if tmp.parent.exists():
                tmp.unlink(missing_ok=True)
            tmp.parent.mkdir(parents=True, exist_ok=True)
            print(f"→ {name}: {url}", flush=True)
            result = subprocess.run(["curl", "-fL", "--retry", "3", "-o", str(tmp), url])
            if result.returncode != 0:
                failures.append((name, url, "curl failed"))
                continue
            actual = hashlib.sha256()
            with tmp.open("rb") as handle:
                for block in iter(lambda: handle.read(1 << 20), b""):
                    actual.update(block)
            if actual.hexdigest() != digest:
                failures.append((name, url, f"sha256 mismatch {actual.hexdigest()}"))
                tmp.unlink(missing_ok=True)
                continue
            target_dir.mkdir(parents=True, exist_ok=True)
            tmp.replace(target)
            print(f"✓ {name}: {target}")
    for name, url, why in failures:
        print(f"✗ {name}: {why} ({url})", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
