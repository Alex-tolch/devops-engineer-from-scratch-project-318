#!/usr/bin/env python3
"""Generate a unique Nginx access-log line and confirm it appears in Loki (via monitoring host)."""
from __future__ import annotations

import json
import os
import shlex
import subprocess
import sys
import time

APP_HOST = os.environ.get("APP_HOST", "64.226.67.71")
MONITORING_HOST = os.environ.get("MONITORING_HOST", "165.232.72.139")
MARKER = os.environ.get("LOKI_TEST_MARKER", "hexlet-loki-smoke-test")
METRICS_PASS = os.environ.get("METRICS_PASS", "")
SSH_KEY = os.path.expanduser(os.environ.get("SSH_KEY", "~/.ssh/id_rsa"))
SSH_USER = os.environ.get("SSH_USER", "root")


def ssh(host: str, remote_cmd: str) -> str:
    return subprocess.check_output(
        ["ssh", "-i", SSH_KEY, f"{SSH_USER}@{host}", remote_cmd],
        text=True,
    )


def main() -> None:
    if not METRICS_PASS:
        print("Set METRICS_PASS (vault_metrics_basic_auth_password)", file=sys.stderr)
        sys.exit(2)
    path = f"/actuator/health?loki_smoke={MARKER}"
    auth = shlex.quote(f"metrics:{METRICS_PASS}")
    url = shlex.quote(f"http://127.0.0.1:9090{path}")
    ssh(APP_HOST, f"curl -s -o /dev/null -u {auth} {url}")
    time.sleep(12)
    logql = f'{{job="nginx-metrics"}} |= "{MARKER}"'
    loki_curl = " ".join(
        [
            "curl -sG",
            shlex.quote("http://127.0.0.1:3100/loki/api/v1/query_range"),
            "--data-urlencode",
            shlex.quote(f"query={logql}"),
            "--data-urlencode",
            shlex.quote("limit=5"),
        ]
    )
    out = ssh(MONITORING_HOST, loki_curl).strip()
    if not out:
        print("Empty response from Loki query API", file=sys.stderr)
        sys.exit(1)
    body = json.loads(out)
    streams = body.get("data", {}).get("result", [])
    if not streams:
        print("No matching lines in Loki. Check Promtail, Loki, and firewall :3100.", file=sys.stderr)
        sys.exit(1)
    print("OK: smoke marker found in Loki (nginx-metrics)")
    print(json.dumps(streams[0], indent=2)[:600])


if __name__ == "__main__":
    main()
