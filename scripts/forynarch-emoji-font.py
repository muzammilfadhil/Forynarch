#!/usr/bin/env python3
"""Install a user-supplied emoji font without root access or network downloads."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import unquote, urlparse
import xml.etree.ElementTree as ET


def install(value):
    uri = urlparse(value)
    if uri.scheme and (uri.scheme != "file" or uri.netloc not in ("", "localhost")):
        raise ValueError("Choose a local font file.")
    path = Path(unquote(uri.path) if uri.scheme else value).expanduser().resolve()
    if not path.is_file() or path.suffix.lower() not in {".ttf", ".otf", ".ttc"}:
        raise ValueError("Choose a TTF, OTF or TTC font file.")
    if not 0 < path.stat().st_size <= 64 * 1024 * 1024:
        raise ValueError("Choose a font smaller than 64 MiB.")
    result = subprocess.run(["fc-scan", "--format", "%{family}\n", str(path)],
                            check=True, capture_output=True, text=True, timeout=15)
    family = next((line.split(",")[0].strip() for line in result.stdout.splitlines() if line.strip()), "")
    if not family or len(family) > 160:
        raise ValueError("The file does not contain a recognized font.")
    root = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "fonts/forynarch-emoji"
    root.mkdir(parents=True, exist_ok=True)
    name = hashlib.sha256(path.read_bytes()).hexdigest()[:24] + path.suffix.lower()
    target = root / name
    if not target.exists():
        fd, temporary = tempfile.mkstemp(dir=root, prefix=".font-")
        try:
            with os.fdopen(fd, "wb") as stream, path.open("rb") as source:
                shutil.copyfileobj(source, stream)
            os.chmod(temporary, 0o644)
            os.replace(temporary, target)
        finally:
            Path(temporary).unlink(missing_ok=True)
    config = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "fontconfig/conf.d"
    config.mkdir(parents=True, exist_ok=True)
    document = ET.Element("fontconfig")
    alias = ET.SubElement(document, "alias", {"binding": "strong"})
    ET.SubElement(alias, "family").text = "emoji"
    prefer = ET.SubElement(alias, "prefer")
    ET.SubElement(prefer, "family").text = family
    ET.SubElement(prefer, "family").text = "Noto Color Emoji"
    if family != "Noto Color Emoji":
        fallback = ET.SubElement(document, "alias", {"binding": "strong"})
        ET.SubElement(fallback, "family").text = "Noto Color Emoji"
        ET.SubElement(ET.SubElement(fallback, "prefer"), "family").text = family
    ET.ElementTree(document).write(config / "60-forynarch-emoji.conf", encoding="utf-8", xml_declaration=True)
    subprocess.run(["fc-cache", "-f", str(root)], check=True, capture_output=True, timeout=30)
    return {"family": family, "file": target.as_uri()}


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2:
            raise ValueError("Choose a local emoji font to install.")
        print(json.dumps(install(sys.argv[1])))
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(str(error) if isinstance(error, ValueError) else "The emoji font could not be installed.", file=sys.stderr)
        sys.exit(1)
