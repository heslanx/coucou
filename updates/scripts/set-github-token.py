#!/usr/bin/env python3
"""Puts the update service's GitHub token into Easypanel, from the Mac's Keychain, without showing it anywhere.

  1. Create the fine-grained token (updates/README.md, "Deploy on Easypanel") and store it in the Keychain, typed at a
     hidden prompt (nothing lands in the shell history):
         security add-generic-password -U -a konclui -s konclui-updates-github-token -w
  2. python3 updates/scripts/set-github-token.py

The token travels from the Keychain to Easypanel in this process's memory only: never printed, never in a file, never in an
environment variable. Easypanel's own API token is read from the infrastructure's documented place
(konclui-project/konclui-bos/backend/.env.local; docs/hub/infrastructure.md, section 4.4). Run it again to rotate the token.
"""
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

KEYCHAIN_SERVICE = "konclui-updates-github-token"
EASYPANEL_ENV = Path.home() / "Developments/konclui-project/konclui-bos/backend/.env.local"
PANEL = "https://epanel.konclui.com"
PROJECT, SERVICE = "backend", "updates"
REPO = "konclui/konclui-notch"
PUBLIC = "https://updates.konclui.com"
AGENT = "konclui-updates-setup"   # Easypanel's firewall refuses Python's default User-Agent


def stop(message: str) -> None:
    print(message, file=sys.stderr)
    sys.exit(1)


def keychain_token() -> str:
    found = subprocess.run(["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"], capture_output=True, text=True)
    if found.returncode != 0 or not found.stdout.strip():
        stop(f"No token in the Keychain yet. Store it at a hidden prompt:\n"
             f"  security add-generic-password -U -a konclui -s {KEYCHAIN_SERVICE} -w")
    token = found.stdout.strip()
    if not token.startswith("github_pat_"):
        stop("The Keychain item is not a fine-grained token (github_pat_…). Use one that reads only "
             f"{REPO}'s contents: a classic token would open every repository.")
    return token


def easypanel_token() -> str:
    for line in EASYPANEL_ENV.read_text().splitlines():
        if line.startswith("EASYPANEL_API_TOKEN="):
            value = line.split("=", 1)[1].strip().strip("'\"")
            if value:
                return value
    stop(f"EASYPANEL_API_TOKEN is missing from {EASYPANEL_ENV}")


def request(url: str, headers: dict, body: bytes | None = None) -> tuple[int, bytes]:
    req = urllib.request.Request(url, data=body, headers={"User-Agent": AGENT, **headers}, method="POST" if body else "GET")
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            return res.status, res.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()


def easypanel(token: str, procedure: str, payload: dict) -> dict:
    status, raw = request(f"{PANEL}/api/trpc/{procedure}",
                          {"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                          json.dumps({"json": payload}).encode())
    if status != 200:
        stop(f"Easypanel refused {procedure} ({status}); nothing of its answer is shown, it can carry secrets.")
    return json.loads(raw or b"{}").get("json") or {}


def main() -> None:
    github = keychain_token()
    status, _ = request(f"https://api.github.com/repos/{REPO}/releases?per_page=1",
                        {"Authorization": f"Bearer {github}", "Accept": "application/vnd.github+json"})
    if status != 200:
        stop(f"The token cannot read {REPO}'s releases (GitHub answered {status}): it needs Contents: Read on that repository.")
    print(f"token: fine-grained, reads {REPO}'s releases")

    panel = easypanel_token()
    service = easypanel(panel, "services.app.inspectService", {"projectName": PROJECT, "serviceName": SERVICE})
    lines = [line for line in (service.get("env") or "").splitlines() if not line.startswith("GITHUB_TOKEN=")]
    lines.append(f"GITHUB_TOKEN={github}")
    easypanel(panel, "services.app.updateEnv", {"projectName": PROJECT, "serviceName": SERVICE, "env": "\n".join(lines)})
    easypanel(panel, "services.app.deployService", {"projectName": PROJECT, "serviceName": SERVICE})
    print("Easypanel: GITHUB_TOKEN set, deploying")

    for _ in range(30):
        time.sleep(5)
        status, raw = request(f"{PUBLIC}/health", {})
        if status == 200 and json.loads(raw).get("configured"):
            status, raw = request(f"{PUBLIC}/v1/mac/releases", {})
            count = len(json.loads(raw)) if status == 200 else None
            print(f"{PUBLIC}: configured; releases answer {status}, {count} Koncluí release(s) offered")
            return
    stop(f"{PUBLIC}/health did not say configured within 150 s; check the service in Easypanel.")


if __name__ == "__main__":
    main()
