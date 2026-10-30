#!/usr/bin/env python3
"""Koncluí K11: what the nb-hook relay sends from an Orca terminal.

Takes the relay scripts embedded in HookServer.swift (GitHub and App Store builds), runs each one
against a throwaway Unix socket in a temp HOME, with the environment of an Orca terminal, and
checks the payload that arrives: the terminal handle and the worktree id are there, no other
ORCA_* value is, and the hook token never is. Nothing outside the temp folder is touched.

usage: python3 -I test-orca-relay.py <HookServer.swift>
"""
import json, os, re, shutil, socket, subprocess, sys, tempfile, threading

failures = 0


def check(name, ok):
    global failures
    print(f"  {'✓' if ok else '✗'} {name}")
    if not ok:
        failures += 1


def embedded_script(source, name):
    """The Python text of `private let <name> = \"\"\" ... \"\"\"`, with Swift's escapes undone."""
    m = re.search(r'private let ' + name + r' = """\n(.*?)\n"""', source, re.S)
    if not m:
        sys.exit(f"{name} not found in HookServer.swift")
    return m.group(1).replace('\\\\', '\\')


def relay(script, socket_rel, args, stdin, env_extra, reply=None):
    """Runs the relay once; returns the payload it sent over the socket (or None)."""
    home = tempfile.mkdtemp(prefix="kn", dir="/tmp")  # short: sun_path is 104 bytes
    try:
        sock_path = os.path.join(home, socket_rel)
        os.makedirs(os.path.dirname(sock_path), exist_ok=True)
        hook = os.path.join(home, "nb-hook.py")
        with open(hook, "w") as f:
            f.write(script)
        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server.bind(sock_path)
        server.listen(1)
        server.settimeout(10)
        received = []

        def serve():
            try:
                conn, _ = server.accept()
                data = b""
                while not data.endswith(b"\n"):
                    chunk = conn.recv(65536)
                    if not chunk:
                        break
                    data += chunk
                received.append(data)
                if reply:
                    conn.sendall(reply)
                conn.close()
            except Exception:
                pass

        t = threading.Thread(target=serve)
        t.start()
        env = {"HOME": home, "PATH": "/usr/bin:/bin"}
        env.update(env_extra)
        subprocess.run([sys.executable, "-I", hook] + args, input=stdin.encode(), env=env,
                       capture_output=True, timeout=30)
        t.join(timeout=12)
        server.close()
        return json.loads(received[0]) if received else None
    finally:
        shutil.rmtree(home, ignore_errors=True)


ORCA_ENV = {
    "TERM_PROGRAM": "Orca",
    "__CFBundleIdentifier": "com.stablyai.orca",
    "ORCA_TERMINAL_HANDLE": "term_6c2544ab-5975-420d-841f-e942347a0344",
    "ORCA_WORKTREE_ID": "68a15f80-c9ba-4703-aeec-8242db4c62a2::/work/tree",
    # Orca's other variables: none of them may reach the app.
    "ORCA_AGENT_HOOK_TOKEN": "TOKEN-must-never-leave-the-terminal",
    "ORCA_AGENT_HOOK_ENDPOINT": "http://127.0.0.1:1/endpoint-must-not-leave",
    "ORCA_PANE_KEY": "pane-key-must-not-leave",
    "ORCA_TAB_ID": "tab-id-must-not-leave",
    "ORCA_USER_DATA_PATH": "/user-data-must-not-leave",
}

EVENT = json.dumps({"hook_event_name": "SessionStart", "session_id": "s1", "cwd": "/tmp"})
ASK = json.dumps({"hook_event_name": "PreToolUse", "session_id": "s1", "cwd": "/tmp",
                  "tool_name": "AskUserQuestion", "tool_input": {"questions": []}})


def main():
    source = open(sys.argv[1], encoding="utf-8").read()
    builds = [
        ("GitHub build", embedded_script(source, "nbHookPythonGitHub"), "Library/Application Support/Konclui/nb.sock"),
        ("App Store build", embedded_script(source, "nbHookPythonAppStore"),
         "Library/Containers/fr.louisraille.Coucou/Data/nb.sock"),
    ]
    for label, script, sock in builds:
        print(f"Relay, {label}")
        check("defined once, used on both the event and the --ask paths",
              script.count("def add_orca_context(") == 1
              and len(re.findall(r"^\s+add_orca_context\(payload\)$", script, re.M)) == 2)

        sent = relay(script, sock, ["SessionStart"], EVENT, ORCA_ENV)
        check("an event arrives", isinstance(sent, dict) and sent.get("hook_event_name") == "SessionStart")
        sent = sent or {}
        check("TERM_PROGRAM and the bundle id still go", sent.get("term_program") == "Orca"
              and sent.get("bundle_id") == "com.stablyai.orca")
        check("the terminal handle goes", sent.get("orca_terminal") == ORCA_ENV["ORCA_TERMINAL_HANDLE"])
        check("the worktree id goes", sent.get("orca_worktree") == ORCA_ENV["ORCA_WORKTREE_ID"])
        extra = sorted(k for k in sent if k.lower().startswith("orca") and k not in ("orca_terminal", "orca_worktree"))
        check("no other Orca field goes", extra == [])
        flat = json.dumps(sent)
        check("the hook token never goes", "TOKEN-must-never" not in flat and "ORCA_AGENT_HOOK" not in flat)
        check("no other ORCA_* value goes", not any(s in flat for s in
              ("endpoint-must-not", "pane-key-must-not", "tab-id-must-not", "user-data-must-not")))

        ask = relay(script, sock, ["--ask"], ASK, ORCA_ENV, reply=b'{"permissionDecision":"ask"}\n')
        check("the --ask path carries the terminal and worktree too", isinstance(ask, dict)
              and ask.get("orca_terminal") == ORCA_ENV["ORCA_TERMINAL_HANDLE"]
              and ask.get("orca_worktree") == ORCA_ENV["ORCA_WORKTREE_ID"]
              and "TOKEN-must-never" not in json.dumps(ask))

        plain = relay(script, sock, ["SessionStart"], EVENT, {"TERM_PROGRAM": "Apple_Terminal"})
        check("outside Orca, no Orca field is added", isinstance(plain, dict)
              and not any(k.startswith("orca") for k in plain) and plain.get("term_program") == "Apple_Terminal")

        handle_only = relay(script, sock, ["SessionStart"], EVENT,
                            {"TERM_PROGRAM": "Orca", "ORCA_TERMINAL_HANDLE": "term_x"})
        check("a handle without a worktree id sends just the handle", isinstance(handle_only, dict)
              and handle_only.get("orca_terminal") == "term_x" and "orca_worktree" not in handle_only)

        empty = relay(script, sock, ["SessionStart"], EVENT,
                      {"TERM_PROGRAM": "Orca", "ORCA_TERMINAL_HANDLE": "", "ORCA_WORKTREE_ID": ""})
        check("empty variables send nothing", isinstance(empty, dict) and not any(k.startswith("orca") for k in empty))

    if failures:
        print(f"\n{failures} failure(s)")
        sys.exit(1)
    print("\nKoncluí relay: all checks passed")


main()
