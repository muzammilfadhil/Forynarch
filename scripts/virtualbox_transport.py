#!/usr/bin/env python3
"""Loopback-only transport for the approved VirtualBox provisioning job."""
import argparse
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--port", type=int, required=True)
    args = parser.parse_args()
    directory = args.directory.resolve()
    allowed = {"/bootstrap.sh": "bootstrap.sh", "/builder.pub": "builder.pub", "/run.sh": "run.sh"}

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_GET(self):
            filename = allowed.get(self.path)
            if filename is None:
                self.send_error(404)
                return
            path = directory / filename
            if not path.is_file() or path.is_symlink():
                self.send_error(404)
                return
            content = path.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)

        def do_POST(self):
            if self.path not in ("/status", "/log"):
                self.send_error(404)
                return
            length = int(self.headers.get("Content-Length", "0"))
            if length < 0 or length > 10 * 1024 * 1024:
                self.send_error(413)
                return
            content = self.rfile.read(length).decode("utf-8", errors="replace")
            if self.path == "/status":
                if content not in ("started", "completed", "failed"):
                    self.send_error(400)
                    return
                (directory / "guest-status.txt").write_text(content, encoding="utf-8")
            else:
                content = re.sub(r"\b[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\b", "[uuid-redacted]", content)
                (directory / "guest-install.log").write_text(content, encoding="utf-8")
            self.send_response(200)
            self.send_header("Content-Length", "0")
            self.end_headers()

    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
