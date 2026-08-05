#!/usr/bin/env python3
"""Optional: list Grafana contact points and POST a direct ntfy smoke test (bypasses ntfy-relay)."""
from __future__ import annotations

import base64
import json
import os
import subprocess
import urllib.request
from pathlib import Path

GRAFANA = os.environ.get("GRAFANA_URL", "http://165.232.72.139:3000")
USER = os.environ.get("GRAFANA_USER", "admin")
ROOT = Path(__file__).resolve().parents[1]
VAULT = ROOT / "ansible/group_vars/app/vault.yml"


def vault_get(key: str) -> str:
    env = os.environ.copy()
    env["ANSIBLE_VAULT_PASSWORD_FILE"] = "/tmp/hexlet-ansible-vault-pass"
    out = subprocess.check_output(
        ["ansible-vault", "view", str(VAULT)],
        env=env,
        cwd=ROOT / "ansible",
        text=True,
    )
    for line in out.splitlines():
        if line.startswith(f"{key}:"):
            return line.split(":", 1)[1].strip()
    raise SystemExit(f"Missing {key} in vault")


def grafana_get(path: str, password: str) -> bytes:
    token = base64.b64encode(f"{USER}:{password}".encode()).decode()
    req = urllib.request.Request(
        f"{GRAFANA}{path}",
        headers={"Authorization": f"Basic {token}", "Accept": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def main() -> None:
    password = os.environ.get("GRAFANA_PASS") or vault_get("vault_grafana_admin_password")
    topic = os.environ.get("NTFY_TOPIC") or vault_get("vault_grafana_ntfy_topic")
    points = json.loads(grafana_get("/api/v1/provisioning/contact-points", password))
    print("Contact points:", [p.get("name") for p in points])
    msg = "Grafana ntfy smoke test (bulletins alerting)"
    data = msg.encode()
    req = urllib.request.Request(
        f"https://ntfy.sh/{topic}",
        data=data,
        method="POST",
        headers={"Title": "Grafana test"},
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        print("ntfy:", resp.status, resp.read()[:80])
    print(f"Subscribe: https://ntfy.sh/{topic}")


if __name__ == "__main__":
    main()
