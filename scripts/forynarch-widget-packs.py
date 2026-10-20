#!/usr/bin/env python3
"""Import data-only desktop widget packs. Never evaluate pack contents as code."""
import argparse
import errno
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile
from urllib.parse import unquote, urlparse

LIMIT = 65536
IDENTIFIER = re.compile(r"[a-z][a-z0-9-]{0,39}\Z")
TOKENS = {"time", "date", "user", "memoryUsed", "memoryTotal", "batteryPercent", "trackTitle", "trackArtist"}


class PackError(ValueError):
    pass


def text(value, name, limit=120):
    if not isinstance(value, str) or not value.strip() or len(value) > limit or any(ord(c) < 32 and c != "\n" for c in value):
        raise PackError(f"{name} must be nonempty text of at most {limit} characters.")
    return value


def fields(value, allowed, name):
    if not isinstance(value, dict) or set(value) - set(allowed):
        raise PackError(f"{name} has unsupported fields. Code, commands and external resources are not supported.")


def integer(value, low, high, name):
    if type(value) is not int or not low <= value <= high:
        raise PackError(f"{name} must be an integer from {low} to {high}.")
    return value


def validate(pack):
    fields(pack, ("schemaVersion", "id", "name", "author", "license", "description", "widgets"), "Pack")
    if type(pack.get("schemaVersion")) is not int or pack["schemaVersion"] != 1:
        raise PackError("This pack requires an unsupported schema version.")
    if not isinstance(pack.get("id"), str) or not IDENTIFIER.fullmatch(pack["id"]):
        raise PackError("Pack id must start with a lowercase letter and contain only lowercase letters, digits or hyphens (up to 40 characters).")
    for name in ("name", "author", "license"):
        text(pack.get(name), name)
    if "description" in pack:
        text(pack["description"], "description", 300)
    widgets = pack.get("widgets")
    if not isinstance(widgets, list) or not 1 <= len(widgets) <= 8:
        raise PackError("A pack must contain 1 to 8 widgets.")
    ids = set()
    for widget in widgets:
        fields(widget, ("id", "name", "height", "items"), "Widget")
        widget_id = widget.get("id")
        if not isinstance(widget_id, str) or not IDENTIFIER.fullmatch(widget_id) or widget_id in ids:
            raise PackError("Widget ids must be unique lowercase identifiers.")
        ids.add(widget_id)
        text(widget.get("name"), "Widget name", 80)
        integer(widget.get("height"), 80, 320, "Widget height")
        items = widget.get("items")
        if not isinstance(items, list) or not 1 <= len(items) <= 8:
            raise PackError("Each widget must contain 1 to 8 items.")
        for item in items:
            kind = item.get("kind") if isinstance(item, dict) else None
            allowed = {"text": ("kind", "text", "size", "color"), "clock": ("kind", "format", "size", "color"), "meter": ("kind", "source", "label"), "divider": ("kind",)}
            if kind not in allowed:
                raise PackError("Item kind must be text, clock, meter or divider.")
            fields(item, allowed[kind], "Item")
            if kind == "text":
                content = text(item.get("text"), "Item text", 300)
                if set(re.findall(r"\{(\w+)\}", content)) - TOKENS:
                    raise PackError("Item text contains an unknown data token.")
            if kind == "clock":
                value = text(item.get("format"), "Clock format", 40)
                if "s" in value:
                    raise PackError("Clock formats update once per minute; seconds are not supported.")
            if kind in ("text", "clock"):
                integer(item.get("size", 13), 10, 32, "Font size")
                color = item.get("color", "text")
                if not isinstance(color, str) or color not in {"accent", "text", "muted"} and not re.fullmatch(r"#[0-9a-fA-F]{6}", color):
                    raise PackError("Color must be accent, text, muted or a six-digit hex color.")
            if kind == "meter":
                if item.get("source") not in ("memory", "battery"):
                    raise PackError("Meter source must be memory or battery.")
                if "label" in item:
                    text(item["label"], "Meter label", 40)
    if len((json.dumps(pack, ensure_ascii=False, indent=2)+"\n").encode()) > LIMIT:
        raise PackError("The formatted widget pack exceeds 64 KiB. Reduce its content.")
    return pack


def local_path(value):
    if os.name == "nt" and re.match(r"^[A-Za-z]:[\\/]", str(value)):
        return Path(value).expanduser()
    url = urlparse(str(value))
    if url.scheme:
        if url.scheme != "file" or url.netloc not in ("", "localhost") or url.query or url.fragment:
            raise PackError("Choose a local JSON file.")
        return Path(unquote(url.path))
    return Path(value).expanduser()


def pairs(entries):
    result = {}
    for key, value in entries:
        if key in result:
            raise PackError(f"Duplicate JSON field: {key}")
        result[key] = value
    return result


def reject_constant(value):
    raise PackError("Nonfinite numbers are not supported.")


def digest(pack):
    return hashlib.sha256(json.dumps(pack, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()).hexdigest()


def read_pack(path):
    if not stat.S_ISREG(path.stat().st_mode):
        raise PackError("Choose a regular JSON file.")
    with path.open("rb") as stream:
        raw = stream.read(LIMIT + 1)
    if len(raw) > LIMIT:
        raise PackError("Widget packs must be at most 64 KiB.")
    return validate(json.loads(raw.decode("utf-8-sig"), object_pairs_hook=pairs, parse_constant=reject_constant))


def folder():
    base = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "forynarch/widget-packs"
    base.mkdir(mode=0o700, parents=True, exist_ok=True)
    return base


def catalog(base):
    packs, warnings = [], []
    for path in sorted(base.glob("*.json")):
        if len(packs) >= 8:
            warnings.append("Only the first 8 valid packs are loaded.")
            break
        try:
            if path.is_symlink():
                raise PackError("Registry symlinks are not supported.")
            pack = read_pack(path)
            if path.name != pack["id"] + ".json":
                raise PackError("The registry filename must match the pack id.")
            if sum(len(row["widgets"]) for row in packs) + len(pack["widgets"]) > 24:
                raise PackError("The installed pack catalog is limited to 24 custom widgets.")
            packs.append(pack)
        except (OSError, UnicodeError, ValueError) as error:
            warnings.append(f"{path.name}: {error}")
    return {"packs": packs, "warnings": warnings, "folder": str(base)}


def atomic_write(path, pack, replace=False):
    if not path.parent.is_dir():
        raise PackError("The destination folder does not exist. Choose an existing folder.")
    if not replace and (path.exists() or path.is_symlink()):
        raise PackError("A file with this name already exists. Choose another name or remove the existing pack first.")
    data = (json.dumps(pack, ensure_ascii=False, indent=2) + "\n").encode()
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".widget-pack-", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        if replace:
            os.replace(temporary, path)
        else:
            try:
                os.link(temporary, path)
            except OSError as error:
                if error.errno not in (errno.EPERM, errno.ENOTSUP, errno.EOPNOTSUPP):
                    raise
                # FAT/exFAT exports cannot use hard links; still refuse overwrite.
                with path.open("xb") as stream:
                    stream.write(data)
                    stream.flush()
                    os.fsync(stream.fileno())
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def sources(base):
    config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "quickshell/forynarch"
    names = ("DesktopWidgets.qml", "ExtraWidget.qml", "WidgetSurface.qml", "WidgetEditor.qml", "WidgetPacks.js", "WidgetLayout.js", "CustomWidget.qml", "ClockFace.qml", "CavaMeter.qml", "GlassCard.qml", "ActionButton.qml", "Icon.qml", "shell.qml")
    if not all((config / name).is_file() for name in names):
        raise PackError("The active desktop widget source files could not be found in your configuration folder.")
    destination = base.parent / "widget-sources"
    destination.mkdir(mode=0o700, parents=True, exist_ok=True)
    for name in names:
        link = destination / name
        target = (config / name).resolve()
        if link.is_symlink() and link.resolve() == target:
            continue
        if link.exists() or link.is_symlink():
            raise PackError(f"Move the conflicting file from the widget source folder first: {name}")
        link.symlink_to(target)
    note = destination / "README.md"
    if not note.exists():
        note.write_text("# Editable widget sources\n\nThese links point to your active QML/JavaScript configuration. Edits change the running desktop; Quickshell reloads source changes. Back up your configuration before editing. QML can execute code as your user, so review code before copying it here.\n\nDesktopWidgets.qml defines the built-in cards; ExtraWidget.qml defines the additional cards. WidgetPacks.js lists names, WidgetLayout.js lists ids and sizes, and shell.qml owns state. Shared helpers such as GlassCard.qml affect other desktop surfaces too.\n\nRead /usr/share/doc/forynarch/docs/wiki/widget-packs.md for the full QML authoring guide. Editing these files needs no sudo.\n")
    return {"folder": str(destination), "files": list(names)}


def browse(value):
    directory = local_path(value).resolve()
    if not directory.is_dir():
        raise PackError("Choose an existing folder.")
    entries = []
    with os.scandir(directory) as listing:
        for entry in listing:
            if entry.name.startswith("."):
                continue
            try:
                is_directory = entry.is_dir()
                if is_directory or entry.name.lower().endswith(".json") and entry.is_file():
                    entries.append({"name": entry.name, "folder": is_directory})
            except OSError:
                continue
            if len(entries) >= 500:
                break
    entries.sort(key=lambda row: (not row["folder"], row["name"].casefold()))
    return {"folder": str(directory), "parent": str(directory.parent), "entries": entries}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("list")
    commands.add_parser("sources")
    commands.add_parser("browse").add_argument("path")
    for command in ("inspect", "import"):
        subparser = commands.add_parser(command)
        subparser.add_argument("path")
        if command == "import":
            subparser.add_argument("--expected-digest")
    commands.add_parser("remove").add_argument("id")
    export = commands.add_parser("export")
    export.add_argument("id")
    export.add_argument("path")
    export.add_argument("--replace", action="store_true")
    args = parser.parse_args(argv)
    base = folder()
    if args.command == "sources":
        return sources(base)
    if args.command == "browse":
        return browse(args.path)
    if args.command == "list":
        return catalog(base)
    if args.command in ("inspect", "import"):
        pack = read_pack(local_path(args.path))
        if args.command == "import":
            if args.expected_digest and args.expected_digest != digest(pack):
                raise PackError("The pack changed after review. Inspect it again before importing.")
            current = catalog(base)["packs"]
            if len(current) >= 8 or sum(len(row["widgets"]) for row in current) + len(pack["widgets"]) > 24:
                raise PackError("Remove an installed pack before importing more (8 packs / 24 custom widgets maximum).")
            atomic_write(base / (pack["id"] + ".json"), pack)
        return {"pack": pack, "dataOnly": True, "digest": digest(pack)}
    if not IDENTIFIER.fullmatch(args.id):
        raise PackError("Invalid pack id.")
    path = base / (args.id + ".json")
    if path.is_symlink():
        raise PackError("Registry symlinks are not supported.")
    if args.command == "remove":
        path.unlink()
        return {"removed": args.id}
    pack = read_pack(path)
    atomic_write(local_path(args.path), pack, args.replace)
    return {"exported": args.id}


if __name__ == "__main__":
    try:
        print(json.dumps(main(), ensure_ascii=False))
    except (OSError, UnicodeError, ValueError) as error:
        print(f"Widget packs: {error}", file=sys.stderr)
        sys.exit(1)
