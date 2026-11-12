import json
import os
import socketserver
import subprocess
import tempfile
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / "scripts" / "coucou-mcp.py"


class CoucouSocketHandler(socketserver.StreamRequestHandler):
    def handle(self):
        request = json.loads(self.rfile.readline())
        self.server.requests.append(request)
        self.wfile.write(b'{"ok":true,"reminder":{"id":"demo-id"}}\n')


class CoucouSocketServer(socketserver.ThreadingUnixStreamServer):
    def __init__(self, path):
        super().__init__(path, CoucouSocketHandler)
        self.requests = []


def run_bridge(socket_path, messages):
    environment = os.environ.copy()
    environment["COUCOU_SOCKET"] = str(socket_path)
    process = subprocess.run(
        ["/usr/bin/python3", "-I", str(BRIDGE)],
        input="".join(json.dumps(message) + "\n" for message in messages),
        text=True,
        capture_output=True,
        env=environment,
        check=True,
    )
    return [json.loads(line) for line in process.stdout.splitlines()]


def main():
    with tempfile.TemporaryDirectory(prefix="coucou-mcp-test-") as directory:
        socket_path = str(Path(directory) / "coucou.sock")
        server = CoucouSocketServer(socket_path)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        try:
            replies = run_bridge(socket_path, [
                {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18"}},
                {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
                {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {
                    "name": "create_reminder",
                    "arguments": {"title": "Review release", "due_at": "2026-10-27T17:30:00Z", "action": "delete_all", "coucou_kind": "statusline"},
                }},
            ])
            assert replies[0]["result"]["protocolVersion"] == "2025-06-18"
            names = [tool["name"] for tool in replies[1]["result"]["tools"]]
            assert names == ["create_reminder", "list_reminders", "dismiss_reminder", "complete_reminder", "snooze_reminder", "stop_reminder"]
            assert replies[2]["result"]["structuredContent"]["ok"] is True
            assert server.requests[0]["coucou_kind"] == "reminder_mcp"
            assert server.requests[0]["action"] == "create"
            assert server.requests[0]["title"] == "Review release"
            assert replies[2]["result"]["isError"] is False
            print("Reminder MCP tests passed")
        finally:
            server.shutdown()
            server.server_close()
            worker.join(timeout=2)


if __name__ == "__main__":
    main()
