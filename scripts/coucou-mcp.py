#!/usr/bin/env python3
"""Local stdio MCP server for creating and managing Coucou reminders."""

import json
import os
import socket
import sys

PROTOCOL_VERSION = "2025-06-18"
SERVER_NAME = "coucou-reminders"
MAX_MESSAGE_BYTES = 1_000_000
DEFAULT_SOCKET = os.path.expanduser("~/Library/Application Support/NotchBuddy/nb.sock")

TOOLS = [
    {
        "name": "create_reminder",
        "description": "Create a private reminder on this Mac. Use HTTPS links only. Use image_base64 for a PNG/JPEG image no larger than 2 MB.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "title": {"type": "string", "maxLength": 120},
                "message": {"type": "string", "maxLength": 2000},
                "due_at": {"type": "string", "description": "ISO 8601 date-time with a timezone, for example 2026-10-27T17:30:00-03:00."},
                "presentation": {"type": "string", "enum": ["card", "fullScreen"]},
                "repeats": {"type": "string", "enum": ["none", "daily", "weekdays", "weekly"]},
                "width": {"type": "number", "minimum": 260, "maximum": 900},
                "height": {"type": "number", "minimum": 180, "maximum": 720},
                "position_x": {"type": "number", "minimum": 0, "maximum": 1},
                "position_y": {"type": "number", "minimum": 0, "maximum": 1},
                "screen_index": {"type": "integer", "minimum": 0, "maximum": 15},
                "snooze_minutes": {"type": "integer", "minimum": 1, "maximum": 1440},
                "symbol": {"type": "string", "maxLength": 64},
                "image_base64": {"type": "string", "maxLength": 950000, "description": "Optional inline PNG/JPEG image data up to 700 KB; no URL is fetched."},
                "buttons": {
                    "type": "array", "maxItems": 3,
                    "items": {"type": "object", "properties": {
                        "title": {"type": "string", "maxLength": 32},
                        "action": {"type": "string", "enum": ["openURL", "snooze", "complete", "dismiss", "stop"]},
                        "url": {"type": "string", "description": "HTTPS URL required for openURL; omitted for other actions."}
                    }, "required": ["title", "action"], "additionalProperties": False}
                }
            },
            "required": ["title", "due_at"],
            "additionalProperties": False
        }
    },
    {"name": "list_reminders", "description": "List reminders stored locally by Coucou on this Mac.", "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False}},
    {"name": "dismiss_reminder", "description": "Dismiss this reminder occurrence. Repeating reminders continue at their next scheduled time.", "inputSchema": {"type": "object", "properties": {"id": {"type": "string", "format": "uuid"}}, "required": ["id"], "additionalProperties": False}},
    {"name": "complete_reminder", "description": "Mark this reminder occurrence complete. Repeating reminders continue at their next scheduled time.", "inputSchema": {"type": "object", "properties": {"id": {"type": "string", "format": "uuid"}}, "required": ["id"], "additionalProperties": False}},
    {"name": "snooze_reminder", "description": "Snooze a reminder for a chosen duration (1 to 1,440 minutes), when snooze is enabled for that reminder.", "inputSchema": {"type": "object", "properties": {"id": {"type": "string", "format": "uuid"}, "minutes": {"type": "integer", "minimum": 1, "maximum": 1440}}, "required": ["id", "minutes"], "additionalProperties": False}},
    {"name": "stop_reminder", "description": "Stop a reminder and cancel all future occurrences.", "inputSchema": {"type": "object", "properties": {"id": {"type": "string", "format": "uuid"}}, "required": ["id"], "additionalProperties": False}},
]

TOOL_ACTIONS = {
    "create_reminder": "create",
    "list_reminders": "list",
    "dismiss_reminder": "dismiss",
    "complete_reminder": "complete",
    "snooze_reminder": "snooze",
    "stop_reminder": "stop",
}


def call_coucou(arguments):
    path = os.environ.get("COUCOU_SOCKET", DEFAULT_SOCKET)
    payload = json.dumps({**arguments, "coucou_kind": "reminder_mcp"}, separators=(",", ":")).encode() + b"\n"
    if len(payload) > MAX_MESSAGE_BYTES:
        raise ValueError("Reminder request exceeds the local message limit.")
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(3)
        client.connect(path)
        client.sendall(payload)
        response = bytearray()
        while len(response) <= MAX_MESSAGE_BYTES:
            chunk = client.recv(4096)
            if not chunk:
                break
            if b"\n" in chunk:
                response.extend(chunk.split(b"\n", 1)[0])
                break
            response.extend(chunk)
    if not response:
        raise RuntimeError("Coucou returned no response.")
    return json.loads(response)


def result(identifier, value):
    return {"jsonrpc": "2.0", "id": identifier, "result": value}


def error(identifier, code, message):
    return {"jsonrpc": "2.0", "id": identifier, "error": {"code": code, "message": message}}


def handle(message):
    if not isinstance(message, dict) or message.get("jsonrpc") != "2.0":
        return error(message.get("id") if isinstance(message, dict) else None, -32600, "Invalid JSON-RPC request.")
    identifier = message.get("id")
    method = message.get("method")
    params = message.get("params") or {}

    if method == "notifications/initialized":
        return None
    if method == "initialize":
        requested = params.get("protocolVersion", PROTOCOL_VERSION)
        version = requested if isinstance(requested, str) and requested.startswith(("2024-", "2025-")) else PROTOCOL_VERSION
        return result(identifier, {"protocolVersion": version, "capabilities": {"tools": {}}, "serverInfo": {"name": SERVER_NAME, "version": "1.0.0"}})
    if method == "ping":
        return result(identifier, {})
    if method == "tools/list":
        return result(identifier, {"tools": TOOLS})
    if method == "tools/call":
        name = params.get("name")
        if name not in TOOL_ACTIONS:
            return error(identifier, -32602, "Unknown Coucou reminder tool.")
        arguments = params.get("arguments") or {}
        if not isinstance(arguments, dict):
            return error(identifier, -32602, "Tool arguments must be an object.")
        try:
            response = call_coucou({**arguments, "action": TOOL_ACTIONS[name]})
        except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
            return result(identifier, {"isError": True, "content": [{"type": "text", "text": str(exc)}]})
        text = json.dumps(response, ensure_ascii=False, separators=(",", ":"))
        return result(identifier, {"isError": not response.get("ok", False), "content": [{"type": "text", "text": text}], "structuredContent": response})
    if identifier is None:
        return None
    return error(identifier, -32601, "Method not found.")


def main():
    for raw_line in sys.stdin.buffer:
        if len(raw_line) > MAX_MESSAGE_BYTES:
            continue
        try:
            message = json.loads(raw_line)
            response = handle(message)
        except (json.JSONDecodeError, TypeError, AttributeError):
            response = error(None, -32700, "Parse error.")
        if response is not None:
            sys.stdout.write(json.dumps(response, ensure_ascii=False, separators=(",", ":")) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
