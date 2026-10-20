#!/usr/bin/env python3
"""Screenshot destinations and bounded, opt-in local clipboard history."""
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import time

MAX_ITEM = 4 * 1024 * 1024
MAX_TOTAL = 16 * 1024 * 1024
MAX_ENTRIES = 50


def locations():
    home = Path.home()
    return (Path(os.environ.get("XDG_CONFIG_HOME", home / ".config")) / "forynarch/capture.json",
            Path(os.environ.get("XDG_STATE_HOME", home / ".local/state")) / "forynarch/clipboard.sqlite3")


def defaults():
    pictures = Path.home() / "Pictures"
    try:
        result = subprocess.run(["xdg-user-dir", "PICTURES"], capture_output=True, text=True, timeout=3)
        if result.returncode == 0 and result.stdout.strip():
            pictures = Path(result.stdout.strip())
    except (OSError, subprocess.TimeoutExpired):
        pass
    return {"saveFiles": True, "copyClipboard": True, "directory": str(pictures / "Screenshots"),
            "historyEnabled": False}


def validate(value):
    if not isinstance(value, dict) or set(value) != {"saveFiles", "copyClipboard", "directory", "historyEnabled"}:
        raise ValueError("Screenshot settings are invalid.")
    if any(type(value[key]) is not bool for key in ("saveFiles", "copyClipboard", "historyEnabled")):
        raise ValueError("Screenshot switches must be true or false.")
    if not value["saveFiles"] and not value["copyClipboard"]:
        raise ValueError("Choose a file destination, the clipboard, or both.")
    directory = value["directory"]
    if not isinstance(directory, str) or not directory.strip() or len(directory) > 4096 or any(ord(c) < 32 for c in directory):
        raise ValueError("Choose a valid screenshot folder.")
    directory = Path(directory).expanduser()
    if not directory.is_absolute():
        raise ValueError("The screenshot folder must use an absolute path.")
    return {**value, "directory": str(directory)}


def preferences():
    config, _ = locations()
    return validate(json.loads(config.read_text()) if config.exists() else defaults())


def set_preference(key, raw):
    value = preferences()
    if key not in value:
        raise ValueError("Unknown screenshot setting.")
    if key != "directory":
        if raw not in {"true", "false"}:
            raise ValueError("Use true or false for switches.")
        raw = raw == "true"
    value[key] = raw
    value = validate(value)
    config, _ = locations()
    config.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor, temporary = tempfile.mkstemp(prefix=".capture-", dir=config.parent)
    try:
        with os.fdopen(descriptor, "w") as stream:
            json.dump(value, stream)
        os.replace(temporary, config)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return value


def screenshot(kind):
    prefs = preferences()
    command = ["grim"]
    if kind == "region":
        selected = subprocess.run(["slurp"], capture_output=True, text=True, timeout=120)
        if selected.returncode != 0 or not selected.stdout.strip():
            return {"cancelled": True}
        command += ["-g", selected.stdout.strip()]
    captured = subprocess.run([*command, "-"], capture_output=True, timeout=30, check=True).stdout
    if not captured.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("The display did not return a PNG screenshot.")
    destination = ""
    if prefs["saveFiles"]:
        directory = Path(prefs["directory"])
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        destination = str(directory / (time.strftime("Screenshot-%Y%m%d-%H%M%S-") + str(time.time_ns())[-9:] + ".png"))
        descriptor, temporary = tempfile.mkstemp(prefix=".screenshot-", dir=directory)
        try:
            with os.fdopen(descriptor, "wb") as stream:
                stream.write(captured)
            os.replace(temporary, destination)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    if prefs["copyClipboard"]:
        subprocess.run(["wl-copy", "--type", "image/png"], input=captured, check=True, timeout=10)
    message = "Saved to " + destination if destination else "Copied to clipboard"
    try:
        subprocess.run(["notify-send", "Screenshot", message], check=False, timeout=3)
    except (OSError, subprocess.TimeoutExpired):
        pass
    return {"saved": destination, "copied": prefs["copyClipboard"]}


def database():
    _, path = locations()
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor = os.open(path, os.O_CREAT | os.O_RDWR, 0o600)
    os.close(descriptor)
    os.chmod(path, 0o600)
    connection = sqlite3.connect(path, timeout=5)
    connection.execute("PRAGMA secure_delete=ON")
    connection.execute("CREATE TABLE IF NOT EXISTS clips (id INTEGER PRIMARY KEY AUTOINCREMENT, digest TEXT UNIQUE, mime TEXT, data BLOB, captured INTEGER)")
    return connection


def store(mime, data):
    if (not preferences()["historyEnabled"] or os.environ.get("CLIPBOARD_STATE") in {"sensitive", "nil", "clear"}
            or not data or len(data) > MAX_ITEM or mime not in {"text/plain", "image/png"}):
        return
    if mime == "image/png" and not data.startswith(b"\x89PNG\r\n\x1a\n"):
        return
    digest = hashlib.sha256(mime.encode() + b"\0" + data).hexdigest()
    connection = database()
    try:
        with connection:
            connection.execute("INSERT INTO clips(digest,mime,data,captured) VALUES(?,?,?,?) ON CONFLICT(digest) DO UPDATE SET captured=excluded.captured",
                               (digest, mime, data, time.time_ns()))
            connection.execute("DELETE FROM clips WHERE id NOT IN (SELECT id FROM clips ORDER BY captured DESC LIMIT ?)", (MAX_ENTRIES,))
            while connection.execute("SELECT coalesce(sum(length(data)),0) FROM clips").fetchone()[0] > MAX_TOTAL:
                connection.execute("DELETE FROM clips WHERE id=(SELECT id FROM clips ORDER BY captured LIMIT 1)")
    finally:
        connection.close()


def history(action, identifier=None):
    connection = database()
    try:
        if action == "list":
            return [{"id": row[0], "mime": row[1], "preview": row[2].decode("utf-8", errors="replace")[:300] if row[1] == "text/plain" else "PNG image",
                     "bytes": len(row[2])} for row in connection.execute("SELECT id,mime,data FROM clips ORDER BY captured DESC LIMIT ?", (MAX_ENTRIES,))]
        if action == "clear":
            with connection:
                connection.execute("DELETE FROM clips")
            connection.execute("VACUUM")
            subprocess.run(["wl-copy", "--clear"], check=True, timeout=5)
            subprocess.run(["wl-copy", "--primary", "--clear"], check=False, timeout=5)
            return
        row = connection.execute("SELECT mime,data FROM clips WHERE id=?", (int(identifier),)).fetchone()
        if row is None:
            raise ValueError("This clipboard entry is no longer available.")
        if action == "copy":
            subprocess.run(["wl-copy", "--type", row[0]], input=row[1], check=True, timeout=10)
        elif action == "delete":
            with connection:
                connection.execute("DELETE FROM clips WHERE id=?", (int(identifier),))
        else:
            raise ValueError("Unknown clipboard action.")
    finally:
        connection.close()


def main(args):
    if args == ["status"]:
        return preferences()
    if len(args) == 3 and args[0] == "set":
        return set_preference(args[1], args[2])
    if args in (["fullscreen"], ["region"]):
        return screenshot(args[0])
    if len(args) == 2 and args[0] == "clipboard-store":
        store(args[1], sys.stdin.buffer.read(MAX_ITEM+1))
        return
    if args == ["clipboard-list"]:
        return history("list")
    if args == ["clipboard-clear"]:
        return history("clear")
    if len(args) == 2 and args[0] in {"clipboard-copy", "clipboard-delete"} and args[1].isdecimal():
        return history(args[0].split("-", 1)[1], args[1])
    raise ValueError("Choose a screenshot or clipboard action.")


if __name__ == "__main__":
    try:
        result = main(sys.argv[1:])
        if result is not None:
            print(json.dumps(result))
    except ValueError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
    except (OSError, sqlite3.Error, subprocess.SubprocessError):
        print("The screenshot or clipboard action could not be completed. Check the selected folder and clipboard tools.", file=sys.stderr)
        sys.exit(1)
