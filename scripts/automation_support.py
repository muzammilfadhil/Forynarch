#!/usr/bin/env python3
"""Builder-only validation and adaptation of installed package examples."""

import argparse
import hashlib
import json
import re
import subprocess
import tarfile
from pathlib import Path, PurePosixPath


class AutomationError(ValueError):
    pass


def read_package_list(path):
    packages = []
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        package = line.split("#", 1)[0].strip()
        if not package:
            continue
        if not re.fullmatch(r"[a-z0-9][a-z0-9@._+\-]*", package):
            raise AutomationError(f"invalid package entry: {package!r}")
        if package in packages:
            raise AutomationError(f"duplicate package: {package}")
        packages.append(package)
    if not packages:
        raise AutomationError("empty package list")
    return packages


def safe_tar_name(name):
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts or "\x00" in name:
        raise AutomationError("unsafe archive path")
    return path


def validate_members(members):
    paths, links = set(), set()
    hardlinks = []
    for member in members:
        path = safe_tar_name(member.name)
        if path in paths:
            raise AutomationError("duplicate archive path")
        paths.add(path)
        if not (member.isfile() or member.isdir() or member.issym() or member.islnk()):
            raise AutomationError("special device/FIFO member forbidden")
        if member.issym():
            links.add(path)
        if member.islnk():
            hardlinks.append(safe_tar_name(member.linkname))
    for path in paths:
        if any(parent in links for parent in path.parents):
            raise AutomationError("archive member traverses a symlink")
    for link in hardlinks:
        if link not in paths or link in links:
            raise AutomationError("invalid hardlink target")


def validate_archive(path):
    process = subprocess.Popen(["zstd", "-dc", "--", str(path)], stdout=subprocess.PIPE)
    try:
        with tarfile.open(fileobj=process.stdout, mode="r|") as archive:
            validate_members(archive)
    finally:
        process.stdout.close()
        result = process.wait()
    if result:
        raise AutomationError("archive decompression failed")


def verify_inventory(core_lines, transaction_lines, installed_lines):
    def inventory(lines, transaction=False):
        result = {}
        for line in lines:
            fields = line.split()
            if not fields:
                continue
            if len(fields) != (3 if transaction else 2) or fields[0] in result:
                raise AutomationError("invalid or duplicate package inventory entry")
            result[fields[0]] = fields[1]
        return result
    expected = inventory(core_lines)
    expected.update(inventory(transaction_lines, transaction=True))
    if expected != inventory(installed_lines):
        raise AutomationError("installed packages differ from reviewed core + transaction")


def partition_nodes(table, disk):
    expected_types = ["c12a7328-f81f-11d2-ba4b-00a0c93ec93b", "0fc63daf-8483-4772-8e79-3d69d8477de4"]
    try:
        partition_table = table["partitiontable"]
        partitions = partition_table["partitions"]
        if partition_table["device"] != disk or partition_table["label"] != "gpt" or len(partitions) != 2:
            raise AutomationError("unexpected GPT partition table")
        nodes = []
        for partition, expected in zip(partitions, expected_types):
            node = partition["node"]
            if (not isinstance(node, str) or not re.fullmatch(re.escape(disk) + r"p?[0-9]+", node)
                    or partition["type"].lower() != expected):
                raise AutomationError("unexpected partition device/type")
            nodes.append(node)
        if len(set(nodes)) != 2:
            raise AutomationError("duplicate partition nodes")
        return nodes
    except (KeyError, TypeError, AttributeError) as error:
        raise AutomationError("malformed partition table") from error


def adapt_installed_example(source, version):
    # No API template is guessed here. The build first queries the installed
    # Hyprland package and passes its packaged Lua example to this adapter.
    if not re.fullmatch(r"0\.56\.2-[0-9.]+", version):
        raise AutomationError("Hyprland adapter needs review for installed release " + version)
    text = source
    for variable, value in (("terminal", "forynarch-terminal"), ("fileManager", "forynarch-files"), ("menu", "forynarch-launcher")):
        pattern = rf'(?m)^(local {variable}\s*=\s*)"[^"\n]*"'
        text, count = re.subn(pattern, lambda match: match[1] + json.dumps(value), text)
        if count != 1:
            raise AutomationError("packaged example shape changed: " + variable)
    # Activate the shipped startup example, replacing its example commands.
    lines = text.splitlines()
    start = next((i for i, line in enumerate(lines)
                  if re.fullmatch(r'\s*--\s*hl\.on\("hyprland\.start", function\s*\(\)\s*', line)), None)
    if start is None:
        raise AutomationError("packaged startup example missing")
    end = next((i for i in range(start + 1, len(lines))
                if re.fullmatch(r'\s*--\s*end\)\s*', lines[i])), None)
    if end is None or end - start > 12:
        raise AutomationError("packaged startup example changed")
    commands = [line for line in lines[start + 1:end] if 'hl.exec_cmd("' in line]
    if not commands:
        raise AutomationError("packaged startup command missing")
    # Reuse the example's existing API statement, modifying only the string.
    command = re.sub(r'^\s*--\s*', '', commands[0])
    command = re.sub(r'"[^"\n]*"', '"forynarch-session-start"', command, count=1)
    lines[start:end + 1] = [re.sub(r'^\s*--\s*', '', lines[start]), command,
                            re.sub(r'^\s*--\s*', '', lines[end])]
    text = "\n".join(lines) + "\n"
    # Keep syntax/API from the checked installed example, change only key/value
    # literals whose expected source occurrences are verified.
    replacements = [('" + R", hl.dsp.exec_cmd(menu)', '" + SPACE", hl.dsp.exec_cmd(menu)'),
                    ('" + V", hl.dsp.window.float', '" + V", hl.dsp.window.float')]
    for before, after in replacements:
        if text.count(before) != 1:
            raise AutomationError("packaged key binding changed")
        text = text.replace(before, after)
    text = text.replace('"rgba(33ccffee)"', '"rgba(76c0ecff)"')
    text = text.replace('"rgba(00ff99ee)"', '"rgba(425b9aff)"')
    text = text.replace('"rgba(595959aa)"', '"rgba(293b5fff)"')
    text = re.sub(r'(?m)^(\s*disable_hyprland_logo\s*=\s*)false(\s*,)', r'\g<1>true\2', text)
    text = re.sub(r'(?m)^(\s*force_default_wallpaper\s*=\s*)-1(\s*,)', r'\g<1>0\2', text)
    # Match only existing settings from the recorded packaged example.
    for name, value in (("gaps_in", 6), ("gaps_out", 14), ("border_size", 1), ("rounding", 10)):
        pattern = rf'(?m)^(\s*{name}\s*=\s*)\d+(\s*,)'
        text, count = re.subn(pattern, lambda match: match[1] + str(value) + match[2], text, count=1)
        if count != 1:
            raise AutomationError("packaged spacing setting changed: " + name)
    # Opaque upstream opacity remains; disable expensive effects by matching
    # exact existing blocks, without adding version-dependent options.
    for section in ("shadow", "blur", "animations"):
        pattern = rf'({section}\s*=\s*\{{\s*enabled\s*=\s*)true'
        text, count = re.subn(pattern, r'\g<1>false', text, count=1)
        if count != 1:
            raise AutomationError("packaged visual block changed: " + section)
    # VirtualBox reports a physical size that can select oversized auto scaling.
    # Keep real monitors on auto; constrain only the VM's known virtual output.
    text += '\n-- Virtual display preview; real displays retain automatic scaling.\n'
    text += 'hl.monitor({ output = "Virtual-1", mode = "preferred", position = "auto", scale = 1 })\n'
    # The 0.15 Waybar workspace click handler still sends old dispatcher syntax.
    # Refresh our five lightweight buttons only on compositor events.
    text += '''
local function refresh_workspace_bar()
    hl.exec_cmd("forynarch-workspace refresh")
end
hl.on("workspace.active", refresh_workspace_bar)
hl.on("config.reloaded", function()
    refresh_workspace_bar()
    hl.exec_cmd("forynarch-motion restore")
    hl.exec_cmd("qs -c forynarch ipc call appearance restoreEffects 2>/dev/null || true")
end)
'''
    text += '''
-- Forynarch modules override only their declared keys/options.
local user_config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
for _, module in ipairs({"identity.lua", "bindings.lua", "windows.lua", "system-settings.lua", "monitors.lua", "workspace-modes.lua", "bindings-user.lua", "auto-snap.lua"}) do
    local path = user_config .. "/hypr/" .. module
    local file = io.open(path, "r")
    if file then file:close(); dofile(path) end
end
'''
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    packages = commands.add_parser("packages")
    packages.add_argument("path", type=Path)
    archive = commands.add_parser("archive")
    archive.add_argument("path", type=Path)
    verify = commands.add_parser("inventory")
    verify.add_argument("core", type=Path)
    verify.add_argument("transaction", type=Path)
    verify.add_argument("installed", type=Path)
    partitions = commands.add_parser("partitions")
    partitions.add_argument("path", type=Path)
    partitions.add_argument("disk")
    adapt = commands.add_parser("adapt")
    adapt.add_argument("source", type=Path)
    adapt.add_argument("version")
    adapt.add_argument("destination", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "packages":
            print("\n".join(read_package_list(args.path)))
        elif args.command == "archive":
            validate_archive(args.path)
            print("Archive path/type validation passed")
        elif args.command == "inventory":
            verify_inventory(args.core.read_text().splitlines(), args.transaction.read_text().splitlines(),
                             args.installed.read_text().splitlines())
            print("Installed package inventory matches the reviewed transaction")
        elif args.command == "partitions":
            print("\n".join(partition_nodes(json.loads(args.path.read_text()), args.disk)))
        else:
            source = args.source.read_text(encoding="utf-8")
            text = adapt_installed_example(source, args.version)
            args.destination.parent.mkdir(parents=True, exist_ok=True)
            args.destination.write_text(text, encoding="utf-8")
            print("Installed example adapted; input sha256=" + hashlib.sha256(source.encode()).hexdigest())
    except (AutomationError, OSError, tarfile.TarError, json.JSONDecodeError) as error:
        parser.exit(2, f"Error: {error}\n")


if __name__ == "__main__":
    main()
