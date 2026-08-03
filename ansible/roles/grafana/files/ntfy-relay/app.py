#!/usr/bin/env python3
"""Accept Grafana webhook JSON and forward plain-text alerts to ntfy."""
from __future__ import annotations

import json
import os
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

NTFY_URL = os.environ.get("NTFY_URL", "https://ntfy.sh").rstrip("/")
NTFY_TOPIC = os.environ["NTFY_TOPIC"]
PORT = int(os.environ.get("PORT", "8088"))


def post_ntfy(text: str, title: str, priority: str = "default") -> None:
    url = f"{NTFY_URL}/{NTFY_TOPIC}"
    req = urllib.request.Request(url, data=text.encode("utf-8"), method="POST")
    req.add_header("Title", title[:250])
    req.add_header("Priority", priority)
    req.add_header("Content-Type", "text/plain; charset=utf-8")
    with urllib.request.urlopen(req, timeout=30) as resp:
        resp.read()


def format_alerts(payload: dict) -> tuple[str, str, str]:
    status = payload.get("status", "unknown")
    alerts = payload.get("alerts") or []
    lines: list[str] = []
    priority = "default"
    for alert in alerts:
        labels = alert.get("labels") or {}
        ann = alert.get("annotations") or {}
        if labels.get("severity") == "critical":
            priority = "high"
        name = labels.get("alertname", "alert")
        st = alert.get("status", status)
        lines.append(f"{st.upper()}: {name}")
        if labels.get("service") or labels.get("severity"):
            lines.append(
                f"service={labels.get('service', '-')} severity={labels.get('severity', '-')}"
            )
        if ann.get("summary"):
            lines.append(str(ann["summary"]))
        if ann.get("description"):
            lines.append(str(ann["description"]))
        lines.append("")
    body = "\n".join(lines).strip() or f"Grafana notification ({status})"
    title = f"Grafana {status}"
    return body, title, priority


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            payload = {
                "status": "unknown",
                "alerts": [
                    {
                        "status": "firing",
                        "annotations": {"summary": raw.decode("utf-8", errors="replace")[:500]},
                    }
                ],
            }
        text, title, priority = format_alerts(payload)
        post_ntfy(text, title, priority)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, fmt: str, *args: object) -> None:
        return


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
