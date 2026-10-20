#!/usr/bin/env python3
"""Date and time settings through systemd's authenticated timedate service."""
import argparse
from datetime import datetime
import json
import re
import subprocess
import sys

def invoke(*arguments):
    return subprocess.run(["timedatectl", *arguments], check=True, capture_output=True, text=True, timeout=120).stdout

def status():
    values = dict(line.split("=", 1) for line in invoke("show").splitlines() if "=" in line)
    return {"timezone": values.get("Timezone", "UTC"), "ntp": values.get("NTP") == "yes",
            "synced": values.get("NTPSynchronized") == "yes", "canNtp": values.get("CanNTP") == "yes",
            "localRtc": values.get("LocalRTC") == "yes"}

def change(action, value):
    if action == "ntp":
        if value not in {"on", "off"}:
            raise ValueError("Choose automatic time on or off.")
        invoke("set-ntp", "true" if value == "on" else "false")
    elif action == "timezone":
        if value not in invoke("list-timezones").splitlines():
            raise ValueError("Choose a timezone from the list.")
        invoke("set-timezone", value)
    elif action == "time":
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?", value or ""):
            raise ValueError("Use YYYY-MM-DD HH:MM:SS for local date and time.")
        parsed = datetime.fromisoformat(value)
        if status()["ntp"]:
            raise ValueError("Turn off automatic time before setting the clock manually.")
        invoke("set-time", parsed.strftime("%Y-%m-%d %H:%M:%S"))
    else:
        raise ValueError("Unknown date and time setting.")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["status", "zones", "ntp", "timezone", "time"])
    parser.add_argument("value", nargs="?")
    args = parser.parse_args()
    if args.action == "zones":
        print(json.dumps(invoke("list-timezones").splitlines()))
        return
    if args.action != "status":
        change(args.action, args.value)
    print(json.dumps(status()))

if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.stderr.strip() or "The system did not authorize the time change.")
    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
        sys.exit(str(error))
