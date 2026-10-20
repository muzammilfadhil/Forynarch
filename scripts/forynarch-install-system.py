#!/usr/bin/python
"""Privileged Live installer transport. Account secrets stay on stdin, never argv."""
import fcntl
from collections import deque
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
for module_dir in (Path(__file__).resolve().parent,Path("/usr/share/forynarch")):
    if (module_dir/"install_layout.py").is_file():
        sys.path.insert(0,str(module_dir));break
from install_layout import prepared_layout

PHASES = {
    "download": "Downloading and checking selected packages",
    "partition": "Preparing the confirmed partition layout",
    "format": "Creating filesystems",
    "extract": "Installing the independent core system",
    "packages": "Installing selected software",
    "account": "Creating your account",
    "flatpak": "Installing selected Flatpak applications",
    "bootloader": "Installing the GRUB boot menu and Particle Circle theme",
    "verify": "Checking the installed package inventory",
    "complete": "Installation completed. Restart when you are ready.",
}
PLAN_FIELDS = {"kind", "revision", "diskId", "offline", "selectedGroups", "filesystem", "sizeGiB", "locale", "timezone", "keyboard", "fullName", "username", "hostname", "selectedDrivers", "passwordless", "reviewOnly"}
TRUSTED_ENV = {"PATH":"/usr/local/sbin:/usr/local/bin:/usr/bin", "HOME":"/root", "LANG":"C.UTF-8", "LC_ALL":"C.UTF-8"}

class PreflightError(ValueError):
    """A public, validated explanation that can be shown by the installer."""


def checked_json(command):
    return json.loads(subprocess.check_output(command, text=True, encoding="utf-8", env=TRUSTED_ENV, stderr=subprocess.PIPE))


def public_fields(request):
    if not isinstance(request, dict) or set(request) != {"plan", "password", "confirmation", "consent"}:
        raise ValueError("Invalid installation request.")
    plan = request["plan"]
    if not isinstance(plan, dict) or not PLAN_FIELDS.issubset(plan) or set(plan)-PLAN_FIELDS-{"rootPartitionId","efiPartitionId","registerBootEntry"}:
        raise ValueError("Installation fields changed. Return to review.")
    return plan


def validate_request(request, inventory, review):
    plan = public_fields(request)
    if plan["kind"] not in ("install-erase","install-manual","install-alongside") or plan["filesystem"] != "ext4" or review.get("canExecute") is not True:
        raise ValueError("This installation method is unavailable.")
    if plan["revision"] != inventory.get("revision"):
        raise ValueError("Disk information changed. Refresh and review again.")
    disks = [disk for disk in inventory.get("disks", []) if disk.get("id") == plan["diskId"]]
    if len(disks) != 1 or not disks[0].get("stableIdentity") or disks[0].get("containsSystem") or disks[0].get("readOnly"):
        raise ValueError("The selected disk is unavailable or protected.")
    disk = disks[0]
    layout=prepared_layout(plan,inventory) if plan["kind"]!="install-erase" else None
    expected="INSTALL "+layout["root"]["path"] if layout else "ERASE "+disk["path"]
    if request["consent"] != expected:
        raise ValueError("Disk-specific confirmation did not match. Disk unchanged.")
    if type(plan["offline"]) is not bool or type(plan["passwordless"]) is not bool:
        raise ValueError("Invalid account or connection choice.")
    if not isinstance(plan["username"], str) or not re.fullmatch(r"[a-z_][a-z0-9_-]{0,30}", plan["username"]) or plan["username"] in {"root", "liveuser", "builder", "nobody"}:
        raise ValueError("Choose a valid account name.")
    if not isinstance(plan["hostname"], str) or not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", plan["hostname"]):
        raise ValueError("Choose a valid computer name.")
    if not isinstance(plan["fullName"], str) or not plan["fullName"].strip() or len(plan["fullName"]) > 100 or any(c in plan["fullName"] for c in "\x00\r\n:"):
        raise ValueError("Choose a valid full name.")
    if plan["keyboard"] not in {"us", "gb", "de", "fr", "es", "br", "jp", "id"} or plan["locale"] != "en_US.UTF-8":
        raise ValueError("Unsupported keyboard or interface language.")
    if not isinstance(plan["timezone"], str) or not re.fullmatch(r"UTC|[A-Za-z_]+(?:/[A-Za-z0-9_+-]+)+", plan["timezone"]):
        raise ValueError("Choose a valid timezone.")
    if not isinstance(plan["selectedGroups"], list) or any(not isinstance(value, str) or not re.fullmatch(r"[a-z0-9][a-z0-9-]*", value) for value in plan["selectedGroups"]) or not isinstance(plan["selectedDrivers"],list) or any(value not in ("intel-vulkan","amd-vulkan") for value in plan["selectedDrivers"]):
        raise ValueError("Unsupported software or driver selection.")
    if plan["offline"] and plan["selectedDrivers"]:raise ValueError("Optional graphics drivers require an online installation.")
    password = request["password"]
    if not isinstance(password, str) or not isinstance(request["confirmation"], str):
        raise ValueError("Invalid password input.")
    if not plan["passwordless"] and (len(password) < 8 or len(password) > 1024 or any(c in password for c in "\x00\r\n") or password != request["confirmation"]):
        raise ValueError("Use matching passwords of at least eight characters.")
    return plan, disk


def installer_arguments(plan, disk_by_id):
    arguments = ["/usr/local/bin/forynarch-install", "--execute", "--gui", "--disk", disk_by_id,
                 "--username", plan["username"], "--hostname", plan["hostname"], "--full-name", plan["fullName"],
                 "--timezone", plan["timezone"], "--keyboard", plan["keyboard"]]
    for identifier in plan["selectedDrivers"]:
        arguments.extend(["--driver",identifier])
    if plan["offline"]:
        arguments.append("--offline")
    if plan["passwordless"]:
        arguments.append("--no-password")
    if plan["kind"]!="install-erase":
        for field,flag in (("rootPartitionId","--root-partition"),("efiPartitionId","--efi-partition")):
            uuid=plan[field].removeprefix("partuuid:")
            if not re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",uuid):raise ValueError("Invalid partition UUID")
            arguments.extend([flag,"/dev/disk/by-partuuid/"+uuid])
        if plan.get("registerBootEntry",False):arguments.append("--register-boot-entry")
    for group in plan["selectedGroups"]:
        arguments += ["--select", group]
    return arguments


def run_installation(arguments, private_input, directory, publish):
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(directory, 0o700)
    phase = "prepare"
    disk_changed = False
    completed = False
    tail = deque(maxlen=60)
    live_tail = deque(maxlen=300)
    last_log_update = 0.0
    secrets = private_input.splitlines()[1:]
    private_bytes = private_input.encode("utf-8")
    logging_warning = ""

    def publish_log(force=False):
        nonlocal last_log_update
        now = time.monotonic()
        if live_tail and (force or now - last_log_update >= 0.25):
            publish({"kind": "log", "text": "\n".join(live_tail)[-49152:]})
            last_log_update = now

    def io_error(operation, error):
        return operation + " (" + type(error).__name__ + ", errno " + str(error.errno) + ")."

    def emit(event):
        nonlocal logging_warning
        event.setdefault("diskMayHaveChanged", disk_changed)
        event["logPath"] = str(directory / "installation.log")
        if logging_warning:
            event["loggingWarning"] = logging_warning
        temporary = directory / "status.tmp"
        try:
            descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            os.fchmod(descriptor, 0o600)
            with os.fdopen(descriptor, "w", encoding="utf-8") as status:
                json.dump(event, status)
            temporary.replace(directory / "status.json")
        except OSError as error:
            logging_warning = io_error("Saving installation status failed", error)
        if logging_warning:
            event["loggingWarning"] = logging_warning
        publish(event)

    descriptor = os.open(directory / "installation.log", os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(descriptor, 0o600)
    with os.fdopen(descriptor, "wb", buffering=0) as log:
        emit({"stage": "prepare", "message": "Checking installation media and confirmed disk"})
        try:
            process = subprocess.Popen(arguments, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT, env=TRUSTED_ENV)
        except OSError as error:
            emit({"stage": "failed", "message": "The installation executor could not start. No disk changes applied.",
                  "failedStage": phase, "exitCode": 127, "details": io_error("Starting installer failed", error)})
            return 127
        try:
            process.stdin.write(private_bytes)
            process.stdin.close()
        except BrokenPipeError:
            pass
        output_error = ""
        log_available = True
        try:
            for raw_line in process.stdout:
                line = raw_line.decode("utf-8", errors="replace")
                for secret in secrets:
                    if secret:
                        line = line.replace(secret, "[redacted]")
                line = re.sub(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b\[[0-?]*[ -/]*[@-~]", "", line)
                line = "".join(character for character in line if character in "\n\t" or ord(character) >= 32 and ord(character) != 127)
                for secret in secrets:
                    if secret:
                        line = line.replace(secret, "[redacted]")
                if log_available:
                    try:
                        data = line.encode("utf-8")
                        if log.write(data) != len(data):
                            raise OSError(28, "Incomplete log write")
                    except OSError as error:
                        logging_warning = io_error("Writing installation log failed", error)
                        log_available = False
                if raw_line.strip() == b"FORYNARCH_DISK_WRITE":
                    disk_changed = True
                    emit({"stage": phase, "message": PHASES.get(phase, "Installing system")})
                    continue
                if raw_line.startswith(b"FORYNARCH_STAGE "):
                    next_phase = raw_line.strip().split(b" ", 1)[1].decode("ascii", errors="replace")
                    if next_phase == "complete":
                        completed = True
                    elif next_phase in PHASES:
                        phase = next_phase
                        if phase in {"partition", "format", "extract", "packages", "account", "flatpak", "bootloader", "verify"}:
                            disk_changed = True
                        emit({"stage": phase, "message": PHASES[phase]})
                        live_tail.append(PHASES[phase])
                        publish_log(force=True)
                elif line.strip():
                    tail.append(line.rstrip()[-2048:])
                    live_tail.append(line.rstrip()[-2048:])
                    publish_log()
        except OSError as error:
            output_error = io_error("Reading installer output failed", error)
        finally:
            process.stdout.close()
        result = process.wait()
        publish_log(force=True)
    if result == 0 and (output_error or not completed):
        result = 1
        output_error = output_error or "The executor exited without its completion marker. Disk state could not be confirmed."
    if output_error:
        tail.append(output_error)
    if logging_warning:
        tail.append(logging_warning)
    message = PHASES["complete"] if result == 0 else (
        "Installation stopped during " + PHASES.get(phase, "preparation").lower() + ". " +
        ("Keep the Live media and check the disk before retrying." if output_error else
         "Keep the Live media for recovery; the selected disk may have changed." if disk_changed else
         "Stopped before disk changes. Check the error details before retrying."))
    emit({"stage": "complete" if result == 0 else "failed", "message": message,
          "failedStage": phase if result else "", "exitCode": result,
          "diskMayHaveChanged": None if output_error else disk_changed,
          "details": "\n".join(tail)[-16000:] if result or logging_warning else ""})
    return result


def main():
    if sys.argv[1:] == ["--diagnostics"] and os.geteuid() == 0 and Path("/run/archiso").is_dir():
        status = Path("/run/forynarch-installation/status.json")
        print(status.read_text() if status.is_file() else json.dumps({"stage": "unavailable", "message": "No installation report is available in this Live session."}))
        return 0
    if len(sys.argv) != 1 or os.geteuid() != 0 or not Path("/run/archiso").is_dir():
        raise ValueError("The system installer runs only from Live media with authorization.")
    request_line = sys.stdin.buffer.readline(32769)
    if len(request_line) > 32768 or not request_line.endswith(b"\n"):
        raise ValueError("Installation request is too large or incomplete.")
    request = json.loads(request_line)
    plan = public_fields(request)
    # The review service receives public fields only, before any target writes.
    inventory = checked_json(["/usr/local/bin/forynarch-installer-info"])
    review = checked_json(["/usr/local/bin/forynarch-installer-review", json.dumps(plan)])
    if review.get("canExecute") is not True:
        reasons=review.get("blockers",[])
        if isinstance(reasons,list) and reasons and all(isinstance(reason,str) and len(reason)<2048 for reason in reasons):
            raise PreflightError("Installation cannot start:\n"+"\n".join(reasons[:12]))
    try:
        plan, disk = validate_request(request, inventory, review)
    except ValueError as error:
        raise PreflightError(str(error)) from None
    aliases = sorted(path for path in Path("/dev/disk/by-id").glob("*") if path.is_symlink() and str(path.resolve()) == disk["path"])
    if not aliases:
        raise ValueError("A stable whole-disk path could not be verified.")
    disk_by_id = str(aliases[0])
    lock = open("/run/forynarch-install.lock", "w")
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    stream_open = True

    def publish(event):
        nonlocal stream_open
        if stream_open:
            try:
                print(json.dumps(event), flush=True)
            except BrokenPipeError:
                stream_open = False
                sys.stdout = open(os.devnull, "w")

    private_input = ("ERASE ALL DATA ON " + disk_by_id if plan["kind"]=="install-erase" else "INSTALL ON /dev/disk/by-partuuid/"+plan["rootPartitionId"].removeprefix("partuuid:")) + "\n"
    if not plan["passwordless"]:
        private_input += request["password"] + "\n"
    arguments = installer_arguments(plan, disk_by_id)
    request.clear()
    publish({"stage": "prepare", "message": "Checking installation media and the confirmed disk"})
    return run_installation(arguments, private_input, Path("/run/forynarch-installation"), publish)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except PreflightError as error:
        print(str(error),file=sys.stderr)
        sys.exit(1)
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as error:
        # Exception details can contain request fragments; never echo them.
        print("The installation helper stopped (" + type(error).__name__ + "). Keep the Live media and inspect the installation log before retrying.", file=sys.stderr)
        sys.exit(1)
