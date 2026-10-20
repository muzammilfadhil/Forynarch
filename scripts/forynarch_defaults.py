"""User application choices, discovered from installed XDG desktop entries."""
import configparser
import json
import os
from pathlib import Path
import shutil
import subprocess

TERMINALS = {
    "Alacritty.desktop": ("alacritty", ["--working-directory"], ["-e"]),
    "kitty.desktop": ("kitty", ["--directory"], []),
    "org.wezfurlong.wezterm.desktop": ("wezterm", ["start", "--cwd"], ["--"]),
    "com.mitchellh.ghostty.desktop": ("ghostty", ["--working-directory"], ["-e"]),
    "org.kde.konsole.desktop": ("konsole", ["--workdir"], ["-e"]),
}
CATEGORIES = {
    "terminal": ("Terminal", []),
    "browser": ("Web browser", ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"]),
    "files": ("File manager", ["inode/directory"]),
    "editor": ("Text editor", ["text/plain"]),
    "pdf": ("PDF documents", ["application/pdf"]),
    "images": ("Images", ["image/png", "image/jpeg", "image/webp"]),
    "audio": ("Audio", ["audio/mpeg", "audio/flac", "audio/ogg"]),
    "video": ("Video", ["video/mp4", "video/webm", "video/x-matroska"]),
}

def preferences():
    return Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "forynarch/default-apps.json"

def applications():
    roots = [Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))]
    roots += [Path(p) for p in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(os.pathsep) if p]
    result, seen = {}, set()
    for root in roots:
        directory = root / "applications"
        for path in sorted(directory.rglob("*.desktop")):
            identity = str(path.relative_to(directory)).replace(os.sep, "-")
            if identity in seen:
                continue
            seen.add(identity)
            try:
                parser = configparser.ConfigParser(interpolation=None, strict=False)
                parser.read(path, encoding="utf-8")
                entry = parser["Desktop Entry"]
                if entry.get("Type") != "Application" or entry.getboolean("Hidden", fallback=False):
                    continue
                if entry.getboolean("NoDisplay", fallback=False):
                    continue
                if entry.get("TryExec") and not shutil.which(entry["TryExec"]):
                    continue
                if not entry.get("Exec"):
                    continue
                result[identity] = {"id": identity, "name": entry.get("Name", identity),
                                    "mime": entry.get("MimeType", "").split(";")}
            except (OSError, ValueError, configparser.Error, KeyError):
                continue
    return result

def terminal_id(apps=None):
    apps = applications() if apps is None else apps
    try:
        selected = json.loads(preferences().read_text()).get("terminal", "")
    except (OSError, ValueError, AttributeError):
        selected = ""
    choices = [key for key, value in TERMINALS.items() if key in apps and shutil.which(value[0])]
    return selected if selected in choices else next(iter(choices), "")

def status():
    apps = applications()
    rows = []
    for key, (name, mimes) in CATEGORIES.items():
        if key == "terminal":
            choices = [app for app in apps.values() if app["id"] in TERMINALS and shutil.which(TERMINALS[app["id"]][0])]
        else:
            choices = [app for app in apps.values() if mimes[0] in app["mime"]]
        selected = terminal_id(apps) if key == "terminal" else subprocess.run(
            ["xdg-mime", "query", "default", mimes[0]], capture_output=True, text=True, check=True, timeout=5).stdout.strip()
        rows.append({"key": key, "name": name, "selected": selected,
                     "choices": sorted(choices, key=lambda app: app["name"].casefold())})
    return {"rows": rows, "terminal": terminal_id(apps)}

def choose(category, identity):
    if category not in CATEGORIES:
        raise ValueError("Unknown application category.")
    row = next(row for row in status()["rows"] if row["key"] == category)
    if identity not in [app["id"] for app in row["choices"]]:
        raise ValueError("Choose an installed application that supports this category.")
    if category != "terminal":
        for mime in CATEGORIES[category][1]:
            subprocess.run(["xdg-mime", "default", identity, mime], check=True, timeout=5)
        return
    path = preferences()
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        data = json.loads(path.read_text())
        if not isinstance(data, dict):
            raise ValueError("Application preferences must be a JSON object.")
    except FileNotFoundError:
        data = {}
    data["terminal"] = identity
    import tempfile
    descriptor, temporary = tempfile.mkstemp(dir=path.parent, prefix=".defaults-")
    try:
        with os.fdopen(descriptor, "w") as output:
            json.dump(data, output, indent=2)
            output.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)

def terminal_command(directory, command, title=None):
    identity = terminal_id()
    if not identity:
        raise ValueError("No supported terminal is installed. Install Alacritty or choose another terminal in Settings.")
    executable, cwd_flags, command_flags = TERMINALS[identity]
    launch = [executable, *cwd_flags, str(directory)]
    if executable == "ghostty":
        launch = [executable, "--working-directory=" + str(directory)]
    if title:
        if executable == "ghostty":
            launch += ["--title=" + title]
        elif executable != "wezterm":
            launch += ["--title", title]
    return launch + command_flags + command if command else launch
