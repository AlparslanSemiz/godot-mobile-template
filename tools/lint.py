#!/usr/bin/env python3
"""Reports GDScript errors and warnings for every project script.

Godot only shows script warnings in the editor, not when the game runs, so this
starts a headless editor with its language server (LSP), opens each .gd file
outside addons/ and prints the diagnostics it publishes. Exit code 1 if any.

Usage: tools/lint.py [--godot PATH]
"""

import argparse
import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {"addons", ".godot", "builds", "android"}
SEVERITY = {1: "ERROR", 2: "WARNING", 3: "INFO", 4: "HINT"}


def send(sock, message):
    body = json.dumps(message).encode()
    sock.sendall(b"Content-Length: %d\r\n\r\n" % len(body) + body)


def read_messages(sock, buffer, timeout):
    """Returns (messages, buffer) read until `timeout` seconds pass with no data."""
    sock.settimeout(timeout)
    messages = []
    while True:
        try:
            chunk = sock.recv(65536)
        except socket.timeout:
            return messages, buffer
        if not chunk:
            return messages, buffer
        buffer += chunk
        while b"\r\n\r\n" in buffer:
            header, rest = buffer.split(b"\r\n\r\n", 1)
            length = int(
                [h for h in header.split(b"\r\n") if h.lower().startswith(b"content-length")][0].split(b":")[1]
            )
            if len(rest) < length:
                break
            messages.append(json.loads(rest[:length]))
            buffer = rest[length:]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--port", type=int, default=6018)
    args = parser.parse_args()

    scripts = sorted(
        p for p in ROOT.rglob("*.gd") if not SKIP_DIRS.intersection(p.relative_to(ROOT).parts)
    )
    editor = subprocess.Popen(
        [args.godot, "--headless", "--editor", "--path", str(ROOT), "--lsp-port", str(args.port)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        sock = None
        for _ in range(120):
            try:
                sock = socket.create_connection(("127.0.0.1", args.port), timeout=1)
                break
            except OSError:
                time.sleep(0.5)
        if sock is None:
            print("lint: language server did not start", file=sys.stderr)
            return 2

        send(sock, {"jsonrpc": "2.0", "id": 1, "method": "initialize",
                    "params": {"processId": os.getpid(), "rootUri": ROOT.as_uri(), "capabilities": {}}})
        _, buffer = read_messages(sock, b"", 3)
        send(sock, {"jsonrpc": "2.0", "method": "initialized", "params": {}})

        diagnostics = {}
        for path in scripts:
            send(sock, {"jsonrpc": "2.0", "method": "textDocument/didOpen", "params": {"textDocument": {
                "uri": path.as_uri(), "languageId": "gdscript", "version": 1, "text": path.read_text()}}})
        # Godot answers each didOpen with a publishDiagnostics notification.
        deadline = time.time() + 60
        while time.time() < deadline and len(diagnostics) < len(scripts):
            messages, buffer = read_messages(sock, buffer, 2)
            for msg in messages:
                if msg.get("method") == "textDocument/publishDiagnostics":
                    diagnostics[msg["params"]["uri"]] = msg["params"]["diagnostics"]
            if not messages:
                break

        problems = 0
        for path in scripts:
            for diag in diagnostics.get(path.as_uri(), []):
                if diag.get("severity", 1) > 2:
                    continue
                problems += 1
                line = diag["range"]["start"]["line"] + 1
                print(f"{path.relative_to(ROOT)}:{line}: {SEVERITY[diag.get('severity', 1)]}: {diag['message']}")
        missing = [p for p in scripts if p.as_uri() not in diagnostics]
        for path in missing:
            print(f"lint: no diagnostics received for {path.relative_to(ROOT)}", file=sys.stderr)
        print(f"lint: {len(scripts)} scripts, {problems} problem(s)")
        return 1 if problems or missing else 0
    finally:
        editor.terminate()
        try:
            editor.wait(timeout=10)
        except subprocess.TimeoutExpired:
            editor.kill()


if __name__ == "__main__":
    sys.exit(main())
