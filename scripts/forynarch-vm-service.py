#!/usr/bin/env python3
"""Authenticated, on-demand existing-OS VM supervision."""
import contextlib
import fcntl
import grp
import json
import os
from pathlib import Path
import pwd
import re
import shutil
import signal
import socket
import stat
import subprocess
import sys
import tempfile
import time
import uuid

sys.path.insert(0, "/usr/local/lib/forynarch")
from forynarch_vm import MIB, SUPPORT_PACKAGES, VmError, flatten, identifier, make_plan, mapper_table, private_gpt, profile, qemu_command, select_partition

RUN = Path("/run/forynarch-vm")
STORE = Path("/var/lib/forynarch-vm")
PROGRAM = "/usr/local/libexec/forynarch-vm-service"
ENV = {"PATH":"/usr/local/sbin:/usr/local/bin:/usr/bin", "LANG":"C.UTF-8", "LC_ALL":"C.UTF-8"}


def command(args, *, data=None, timeout=30, pass_fds=(), check=True):
    result = subprocess.run(args, input=data, capture_output=True, text=True, timeout=timeout, env=ENV, pass_fds=pass_fds)
    if check and result.returncode:
        raise VmError("A required virtualization operation failed. No source repair or forced mount was attempted.")
    return result


def directory(path, *, owner=0, group=0, mode=0o700):
    path.mkdir(exist_ok=True, mode=mode)
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != owner or info.st_mode & 0o022:
        raise VmError("The managed VM directory has unsafe ownership or permissions.")
    os.chown(path, owner, group); os.chmod(path, mode)
    return path


def locations(uid, key):
    identifier(key)
    account = pwd.getpwuid(uid)
    if uid < 1000 or account.pw_uid == 0:
        raise VmError("Virtual machines must belong to a desktop user.")
    for base in (RUN, STORE):
        directory(base, mode=0o755)
        directory(base / str(uid), group=account.pw_gid, mode=0o750)
        directory(base / str(uid) / key, group=account.pw_gid, mode=0o750)
    return RUN / str(uid) / key, STORE / str(uid) / key


def atomic(path, value, gid=0, public=False):
    temporary = path.with_name(".state-" + uuid.uuid4().hex)
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o640 if public else 0o600)
    try:
        os.fchown(fd, 0, gid)
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream); stream.flush(); os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def read_root(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd) as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o022 or info.st_size > 65536:
            raise VmError("The managed VM request is invalid.")
        return json.load(stream)


def unit_name(uid, key):
    identifier(key)
    return f"forynarch-vm-{uid}-{key.replace('-', '')}.service"


def active(uid, key):
    value = command(["systemctl", "show", "--property=ActiveState", "--value", unit_name(uid,key)], check=False).stdout.strip()
    return value in {"active", "activating", "deactivating", "reloading"}


def inventory():
    data = json.loads(command(["lsblk", "--json", "--bytes", "--output", "NAME,PATH,TYPE,SIZE,FSTYPE,LABEL,UUID,PARTUUID,PARTTYPE,MAJ:MIN,MOUNTPOINTS,RO,LOG-SEC,WWN,SERIAL,MODEL"]).stdout)
    rows = flatten(data["blockdevices"])
    for row in rows:
        identity = row.get("maj:min", "")
        if not isinstance(identity,str) or not re.fullmatch(r"\d+:\d+", identity):
            row["holders"] = ["unknown"]
            continue
        holders = Path("/sys/dev/block") / identity / "holders"
        row["holders"] = [p.name for p in holders.iterdir()] if holders.is_dir() else ["unknown"]
    return rows


def collect(document):
    if Path("/var/lib/pacman/db.lck").exists():raise VmError("Wait for the package transaction to finish before preparing a VM.")
    p = profile(document); rows = inventory()
    source = select_partition(rows, p["osPartuuid"])
    parent = source["parent"]
    table = json.loads(command(["sfdisk", "--json", parent]).stdout)["partitiontable"]
    memory = {key:int(value.split()[0])*1024 for key,value in (line.split(":",1) for line in Path("/proc/meminfo").read_text().splitlines())}
    probe = None
    if str(source.get("fstype") or "").lower() in {"ntfs", "ntfs3"}:
        probe = command(["ntfs-3g.probe", "--readwrite", source["path"]], check=False).returncode
        if probe == 0 and p["family"] == "windows":
            found = command(["ntfsls", "-p", "/Windows/System32/config", source["path"]], check=False)
            if found.returncode or "SYSTEM" not in found.stdout.split():
                raise VmError("The selected NTFS volume does not contain a Windows system installation.")
    plan=make_plan(p, rows, table, available_bytes=memory["MemAvailable"], total_bytes=memory["MemTotal"], host_cpus=os.cpu_count() or 1, ntfs_probe=probe)
    identities={plan["source"]["maj:min"],plan["diskNumber"]}
    deadline=time.monotonic()+3
    while True:
        blocker=None
        for process in Path("/proc").iterdir():
            if not process.name.isdecimal() or int(process.name)==os.getpid():continue
            try:
                for fd in (process/"fd").iterdir():
                    try:info=fd.stat()
                    except OSError:continue
                    if stat.S_ISBLK(info.st_mode) and f"{os.major(info.st_rdev)}:{os.minor(info.st_rdev)}" in identities:
                        blocker=process.name
                        break
            except OSError:continue
            if blocker:break
        if not blocker:break
        if time.monotonic()>=deadline:
            raise VmError(f"Process {blocker} has this OS volume or its disk open. Close storage and encryption utilities, then review again.")
        time.sleep(.1)
    return plan


@contextlib.contextmanager
def efi_tree(row):
    fd = os.open(row["path"], os.O_RDONLY | os.O_NOFOLLOW)
    temporary, mounted = None, False
    try:
        info = os.fstat(fd)
        if not stat.S_ISBLK(info.st_mode) or f"{os.major(info.st_rdev)}:{os.minor(info.st_rdev)}" != row["maj:min"]:
            raise VmError("The EFI device changed. Scan again.")
        roots = [Path(p) for p in row.get("mountpoints", []) or [] if p and p.startswith("/")]
        if roots:
            root = roots[0].resolve()
            if root.stat().st_dev != info.st_rdev:
                raise VmError("The EFI mount identity changed.")
        else:
            directory(RUN, mode=0o755)
            temporary = tempfile.mkdtemp(prefix="efi-read-", dir=RUN)
            root = Path(temporary)
            command(["mount", "-t", "vfat", "-o", "ro,nosuid,nodev,noexec", f"/proc/self/fd/{fd}", str(root)], pass_fds=(fd,))
            mounted = True
        yield root
    finally:
        try:
            if mounted:
                command(["umount", str(root)])
                mounted = False
            if temporary and not mounted: os.rmdir(temporary)
        finally: os.close(fd)


def efi_file(root, relative):
    path = root / relative
    resolved = path.resolve()
    if not resolved.is_relative_to(root) or not path.is_file() or path.is_symlink() or path.stat().st_dev != root.stat().st_dev:
        raise VmError("The selected EFI executable is missing or outside the EFI partition.")
    return path


def validate_efi(plan):
    with efi_tree(plan["efiSource"]) as root:
        efi_file(root, plan["profile"]["efiPath"])


def image_file(path, length):
    fd = os.open(path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    info = os.fstat(fd)
    if not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or info.st_nlink != 1:
        os.close(fd); raise VmError("The managed VM image is unsafe.")
    os.ftruncate(fd, 0); os.ftruncate(fd, length)
    return fd


def prepare_images(plan, store):
    primary, backup = private_gpt(plan)
    fd = image_file(store / "metadata.img", 2*MIB)
    try:
        os.pwrite(fd, primary, 0); os.pwrite(fd, backup, 2*MIB-len(backup)); os.fsync(fd)
    finally: os.close(fd)
    image = store / "efi.img"
    fd = image_file(image, plan["efiSectors"]*plan["sectorSize"]); os.close(fd)
    command(["mkfs.fat", "-F", "32", "-S", str(plan["sectorSize"]), "-n", "FORYN_VM", str(image)])
    with efi_tree(plan["efiSource"]) as root:
        selected = efi_file(root, plan["profile"]["efiPath"])
        vendor = root / "EFI" / Path(plan["profile"]["efiPath"]).parts[1]
        source_tree = vendor if vendor.name.lower()!="linux" else selected
        device = root.stat().st_dev
        count = 0
        for folder, directories, files in os.walk(source_tree if source_tree.is_dir() else source_tree.parent, followlinks=False):
            for name in directories + files:
                entry = Path(folder) / name; info = entry.lstat(); count += 1
                if count > 65536 or info.st_dev != device or not (stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode)):
                    raise VmError("The EFI tree contains unsupported entries or another filesystem.")
        command(["mmd", "-i", str(image), "::/EFI"])
        if source_tree.is_dir():
            command(["mcopy", "-s", "-i", str(image), str(source_tree), "::/EFI/"], timeout=120)
        else:
            current=""
            for part in Path(plan["profile"]["efiPath"]).parts[:-1]:
                current+="/"+part
                command(["mmd","-i",str(image),"::"+current],check=False)
            command(["mcopy","-i",str(image),str(selected),"::/"+plan["profile"]["efiPath"]])
        command(["mmd", "-i", str(image), "::/EFI/BOOT"], check=False)
        command(["mcopy", "-o", "-i", str(image), str(selected), "::/EFI/BOOT/BOOTX64.EFI"])


def firmware():
    directory_path = Path("/usr/share/edk2/x64")
    for code, variables in (("OVMF_CODE.4m.fd","OVMF_VARS.4m.fd"),("OVMF_CODE.fd","OVMF_VARS.fd")):
        if (directory_path/code).is_file() and (directory_path/variables).is_file():
            return directory_path/code, directory_path/variables
    raise VmError("Install compatible OVMF firmware before launching a VM.")


def ensure_kvm():
    if not Path("/dev/kvm").exists():
        flags=Path("/proc/cpuinfo").read_text().split()
        module="kvm_intel" if "vmx" in flags else "kvm_amd" if "svm" in flags else None
        if module:command(["modprobe",module],check=False)
    if not Path("/dev/kvm").exists():raise VmError("Hardware virtualization is unavailable. Enable it in firmware, or restart after a kernel update.")


def qmp(path, action):
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(3); connection.connect(str(path))
        stream = connection.makefile("rwb")
        def message():
            for _ in range(32):
                line = stream.readline(65537)
                if not line or len(line)>65536: raise VmError("The VM control connection closed.")
                value=json.loads(line)
                if "event" not in value: return value
            raise VmError("The VM control connection is busy.")
        message()
        for request in ("qmp_capabilities", action):
            stream.write(json.dumps({"execute":request}).encode()+b"\n"); stream.flush()
            response=message()
            if "error" in response: raise VmError("The VM did not accept that control request.")


def device_number(path):
    info = os.stat(path)
    if not stat.S_ISBLK(info.st_mode): raise VmError("A managed block device is unavailable.")
    return f"{os.major(info.st_rdev)}:{os.minor(info.st_rdev)}"


def managed_name(uid, key):
    return f"forynarch-vm-{uid}-{key.replace('-', '')}"


def release_resources(uid, key):
    run, store = locations(uid,key)
    path = run / "resources.json"
    if not path.exists(): return
    resources=read_root(path)
    name=managed_name(uid,key)
    found=command(["dmsetup","info","-c","--noheadings","-o","uuid",name],check=False)
    if found.returncode==0:
        if found.stdout.strip()!=f"FORYNARCH-VM-{uid}-{key}": raise VmError("A foreign device mapping cannot be removed.")
        mapped=Path("/dev/mapper")/name
        fd=os.open(mapped,os.O_RDONLY)
        try:os.fsync(fd)
        finally:os.close(fd)
        if resources.get("direct"):
            source=resources["source"]
            fd=os.open(source["path"],os.O_RDONLY|os.O_NOFOLLOW)
            try:
                if device_number(source["path"])!=source["maj:min"]: raise VmError("The source identity changed during cleanup.")
                fcntl.ioctl(fd,0x1261)  # Invalidate source alias caches before releasing the exclusive mapping.
            finally: os.close(fd)
        command(["dmsetup","remove","--retry",name])
    for loop in resources.get("loops",[]):
        found=command(["losetup","--list","--json","--output","NAME,BACK-FILE",loop],check=False)
        if found.returncode: continue
        for entry in json.loads(found.stdout).get("loopdevices",[]):
            backing=Path(entry["back-file"])
            if backing not in {store/"metadata.img",store/"efi.img"}: raise VmError("A foreign loop device cannot be detached.")
            command(["losetup","--detach",loop])
    (store/"preview.qcow2").unlink(missing_ok=True)
    path.unlink(missing_ok=True)


def cleanup(uid,key):
    run,_=locations(uid,key);gid=pwd.getpwuid(uid).pw_gid
    try:
        release_resources(uid,key)
        if (run/"state.json").exists():
            data=read_root(run/"state.json")
            if data.get("phase")=="cleanup-required":
                atomic(run/"state.json",{"id":key,"phase":"error","error":"Inactive VM resources have been released."},gid,True)
    except (OSError,VmError,subprocess.SubprocessError):
        atomic(run/"state.json",{"id":key,"phase":"cleanup-required","error":"The VM stopped, but its managed storage still needs cleanup. Use Release resources before mounting the OS volume."},gid,True)
        raise


def forget(uid,key):
    run,store=locations(uid,key)
    if active(uid,key):raise VmError("Shut down this VM before deleting its private data.")
    cleanup(uid,key)
    allowed={"metadata.img","efi.img","variables.fd","firmware-input.json","preview.qcow2","qemu.log"}
    for base in (store/"tpm",store):
        if not base.exists():continue
        if base.is_symlink():raise VmError("The private VM data folder is unsafe.")
        fd=os.open(base,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
        try:
            for name in os.listdir(fd):
                if base==store and name=="tpm":continue
                info=os.stat(name,dir_fd=fd,follow_symlinks=False)
                if not stat.S_ISREG(info.st_mode) or info.st_dev!=os.fstat(fd).st_dev or info.st_nlink!=1 or (base==store and name not in allowed):
                    raise VmError("Private VM data contains unexpected entries. Inspect it before removal.")
                os.unlink(name,dir_fd=fd)
        finally:os.close(fd)
        if base!=store:base.rmdir()
    store.rmdir()


def create_mapping(plan, uid, key):
    run, store=locations(uid,key)
    resources={"loops":[],"direct":plan["profile"]["mode"]=="direct","source":{k:plan["source"][k] for k in ("path","maj:min")}}
    atomic(run/"resources.json",resources)
    loops=[]
    for image in ("metadata.img","efi.img"):
        args=["losetup","--find","--show","--sector-size",str(plan["sectorSize"])]
        if not resources["direct"]: args.append("--read-only")
        loop=command([*args,str(store/image)]).stdout.strip()
        if not re.fullmatch(r"/dev/loop[0-9]+",loop): raise VmError("The managed loop device is invalid.")
        loops.append(loop);resources["loops"]=loops;atomic(run/"resources.json",resources)
    table=mapper_table(plan,device_number(loops[0]),device_number(loops[1]),plan["source"]["maj:min"])
    name=managed_name(uid,key)
    args=["dmsetup","create",name,"--uuid",f"FORYNARCH-VM-{uid}-{key}","--noudevrules","--noudevsync"]
    if not resources["direct"]: args.append("--readonly")
    command(args,data=table)
    command(["dmsetup","mknodes",name])
    return Path("/dev/mapper")/name


def desktop_environment(uid, wayland):
    account=pwd.getpwuid(uid)
    if not isinstance(wayland,str) or not re.fullmatch(r"wayland-[0-9]+",wayland): raise VmError("The desktop display is invalid.")
    runtime=Path("/run/user")/str(uid)
    info=(runtime/wayland).lstat()
    if not stat.S_ISSOCK(info.st_mode) or info.st_uid!=uid: raise VmError("The desktop display does not belong to this user.")
    return {**ENV,"HOME":account.pw_dir,"USER":account.pw_name,"LOGNAME":account.pw_name,"XDG_RUNTIME_DIR":str(runtime),"WAYLAND_DISPLAY":wayland,
            "GDK_BACKEND":"wayland","DBUS_SESSION_BUS_ADDRESS":f"unix:path={runtime}/bus"}


def run_guest(uid, key, *, software=False, headless=False):
    run,store=locations(uid,key);account=pwd.getpwuid(uid)
    def state(phase,error=""):
        atomic(run/"state.json",{"id":key,"phase":phase,"error":error},account.pw_gid,True)
    request=read_root(run/"request.json");child=tpm=None;fds=[];pins=[];stopping=[False];diagnostic=None
    signal.signal(signal.SIGTERM,lambda *_:stopping.__setitem__(0,True))
    signal.signal(signal.SIGINT,lambda *_:stopping.__setitem__(0,True))
    try:
        state("preparing")
        plan=collect(request["profile"])
        if plan["digest"]!=request["digest"]: raise VmError("The reviewed storage plan changed. Review it again.")
        for path,number in ((plan["source"]["path"],plan["source"]["maj:min"]),(plan["source"]["parent"],plan["diskNumber"])):
            fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW);pins.append(fd)
            info=os.fstat(fd)
            if not stat.S_ISBLK(info.st_mode) or f"{os.major(info.st_rdev)}:{os.minor(info.st_rdev)}"!=number:
                raise VmError("The source device changed before launch.")
        if not software:ensure_kvm()
        free=shutil.disk_usage(STORE).free
        if free < plan["efiSectors"]*plan["sectorSize"]+8*1024**3: raise VmError("Keep at least 8 GiB free for temporary VM storage.")
        prepare_images(plan,store)
        if stopping[0]: raise VmError("VM startup was cancelled.")
        # Recheck immediately before the kernel takes exclusive partition claims.
        current=collect(request["profile"])
        if current["digest"]!=plan["digest"]: raise VmError("The source changed while preparing EFI. Review it again.")
        mapped=create_mapping(plan,uid,key)
        guest=directory(run/"guest",owner=0,group=account.pw_gid,mode=0o750) if not (run/"guest").exists() else run/"guest"
        if guest.lstat().st_uid not in {0,uid} or not guest.is_dir() or guest.is_symlink(): raise VmError("The VM runtime folder is unsafe.")
        os.chown(guest,uid,account.pw_gid);os.chmod(guest,0o700)
        for name in ("tpm.sock","qmp.sock"):
            path=guest/name
            if path.exists() or path.is_symlink(): path.unlink()
        tpm_path=store/"tpm"
        if not tpm_path.exists(): tpm_path.mkdir(mode=0o700);os.chown(tpm_path,uid,account.pw_gid)
        if tpm_path.is_symlink() or tpm_path.lstat().st_uid!=uid: raise VmError("The virtual TPM state is unsafe.")
        env=ENV if headless else desktop_environment(uid,request["wayland"])
        tpm=subprocess.Popen(["/usr/bin/swtpm","socket","--tpm2","--tpmstate",f"dir={tpm_path}","--ctrl",f"type=unixio,path={guest}/tpm.sock","--terminate"],user=uid,group=account.pw_gid,extra_groups=[],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        for _ in range(100):
            if (guest/"tpm.sock").exists(): break
            if tpm.poll() is not None: raise VmError("The virtual TPM could not start.")
            time.sleep(.05)
        else: raise VmError("The virtual TPM did not become ready.")
        code,template=firmware()
        variables=store/"variables.fd"
        input_key={k:request["profile"][k] for k in ("efiPartuuid","efiPath")}
        if not variables.exists() or not (store/"firmware-input.json").exists() or read_root(store/"firmware-input.json")!=input_key:
            fd=image_file(variables,0)
            with os.fdopen(fd,"wb") as target, template.open("rb") as source: shutil.copyfileobj(source,target)
            atomic(store/"firmware-input.json",input_key)
        direct=plan["profile"]["mode"]=="direct"
        access=os.O_RDWR if direct else os.O_RDONLY
        source_fd=os.open(mapped,access|os.O_DIRECT);fds.append(source_fd)
        source_reopen_fds=[]
        for flags in ([os.O_RDONLY,os.O_RDONLY|os.O_DIRECT,os.O_RDWR] if direct else [os.O_RDONLY]):
            fd=os.open(mapped,flags);source_reopen_fds.append(fd);fds.append(fd)
        variables_fd=os.open(variables,os.O_RDWR|os.O_NOFOLLOW);fds.append(variables_fd)
        variables_read_fd=os.open(variables,os.O_RDONLY|os.O_NOFOLLOW);fds.append(variables_read_fd)
        overlay_fd=overlay_read_fd=None
        if plan["profile"]["mode"]=="preview":
            overlay=store/"preview.qcow2";overlay.unlink(missing_ok=True)
            command(["qemu-img","create","-f","qcow2","-F","raw","-b",str(mapped),str(overlay)],timeout=60)
            overlay_fd=os.open(overlay,os.O_RDWR|os.O_NOFOLLOW);fds.append(overlay_fd)
            overlay_read_fd=os.open(overlay,os.O_RDONLY|os.O_NOFOLLOW);fds.append(overlay_read_fd)
        args=qemu_command(plan,str(code),str(guest),source_fd=source_fd,source_reopen_fds=source_reopen_fds,overlay_fd=overlay_fd,overlay_read_fd=overlay_read_fd,variables_fd=variables_fd,variables_read_fd=variables_read_fd,software=software,headless=headless)
        groups=[grp.getgrnam("kvm").gr_gid] if not software else []
        diagnostic=os.fdopen(image_file(store/"qemu.log",0),"wb",buffering=0)
        child=subprocess.Popen(args,user=uid,group=account.pw_gid,extra_groups=groups,env=env,pass_fds=tuple(fds),cwd=guest,stdout=subprocess.DEVNULL,stderr=diagnostic,umask=0o077)
        state("running");requested=False;deadline=None;paused=False
        while child.poll() is None:
            if os.fstat(diagnostic.fileno()).st_size>MIB:
                os.ftruncate(diagnostic.fileno(),0);os.lseek(diagnostic.fileno(),0,os.SEEK_SET)
            if stopping[0] and not requested:
                with contextlib.suppress(OSError,VmError): qmp(guest/"qmp.sock","system_powerdown")
                requested=True;deadline=time.monotonic()+110
            if deadline and time.monotonic()>deadline:
                with contextlib.suppress(OSError,VmError): qmp(guest/"qmp.sock","quit")
                child.wait(timeout=10);break
            if plan["profile"]["mode"]=="preview" and not paused and shutil.disk_usage(STORE).free<2*1024**3:
                qmp(guest/"qmp.sock","stop");paused=True
                state("paused","Temporary storage is low. Discard this preview to release its temporary changes.")
            time.sleep(.25)
        if child.returncode: raise VmError("QEMU stopped unexpectedly. Native Windows boot and hardware compatibility have not been certified.")
        state("stopped")
    except Exception as error:
        state("error",str(error) if isinstance(error,VmError) else "The VM could not complete this operation.")
        raise
    finally:
        for process in (child,tpm):
            if process and process.poll() is None:
                process.terminate()
                try:process.wait(timeout=10)
                except subprocess.TimeoutExpired:process.kill();process.wait()
        for fd in fds:
            with contextlib.suppress(OSError):os.fsync(fd)
            os.close(fd)
        if diagnostic:diagnostic.close()
        try:cleanup(uid,key)
        finally:
            for fd in pins:os.close(fd)


def main():
    if os.geteuid()!=0: raise VmError("Use system authentication for this operation.")
    action=sys.argv[1] if len(sys.argv)>1 else ""
    if action in {"run","cleanup"}:
        if "PKEXEC_UID" in os.environ or not os.environ.get("INVOCATION_ID"):
            raise VmError("This action is reserved for the VM supervisor.")
        if len(sys.argv)!=4 or not sys.argv[2].isdecimal(): raise VmError("Invalid supervised VM identity.")
        uid=int(sys.argv[2]);key=identifier(sys.argv[3])
        (run_guest if action=="run" else cleanup)(uid,key)
        if action=="cleanup" and os.environ.get("SERVICE_RESULT","success")!="success":
            run,_=locations(uid,key)
            atomic(run/"state.json",{"id":key,"phase":"error","error":"The VM supervisor stopped unexpectedly. Its managed disks have been released; guest changes may not be saved."},pwd.getpwuid(uid).pw_gid,True)
        return
    if len(sys.argv)!=2: raise VmError("Choose a supported virtual-machine action.")
    uid=int(os.environ.get("PKEXEC_UID","0"));account=pwd.getpwuid(uid)
    if uid<1000: raise VmError("Authorize this operation from a desktop user account.")
    if action=="support-install":
        result=subprocess.run(["/usr/bin/systemd-run","--unit=forynarch-vm-support-install","--collect","--wait","--property=Type=exec","--","/usr/bin/pacman","-Syu","--needed","--noconfirm","--",*SUPPORT_PACKAGES],env=ENV,stdout=sys.stderr,stderr=sys.stderr)
        if result.returncode:raise VmError("VM support installation or the system update failed.")
        print(json.dumps({"installed":True}));return
    raw=sys.stdin.buffer.read(65537)
    if len(raw)>65536: raise VmError("The VM request is too large.")
    request=json.loads(raw)
    if not isinstance(request,dict): raise VmError("The VM request is invalid.")
    if action in {"recover","forget"}:
        expected={"id","deleteConfirmed"} if action=="forget" else {"id"}
        if set(request)!=expected or (action=="forget" and request["deleteConfirmed"] is not True):raise VmError("Confirm the managed VM resource operation.")
        key=identifier(request["id"])
        if active(uid,key):raise VmError("Shut down the VM before releasing its storage.")
        (forget if action=="forget" else cleanup)(uid,key)
        print(json.dumps({"released":True}));return
    if action=="loaders":
        if set(request)!={"efiPartuuid"}: raise VmError("The EFI request is invalid.")
        row=select_partition(inventory(),identifier(request["efiPartuuid"]),efi=True)
        with efi_tree(row) as root:
            paths=[]
            for path in (root/"EFI").rglob("*"):
                if len(paths)>=512:break
                if path.suffix.lower()==".efi" and path.is_file():
                    relative=path.relative_to(root).as_posix()
                    with contextlib.suppress(VmError):
                        probe={"id":str(uuid.uuid4()),"name":"EFI","osPartuuid":str(uuid.uuid4()),"efiPartuuid":request["efiPartuuid"],"efiPath":relative,"family":"other","mode":"preview","memoryMiB":512,"cpus":1,"controller":"auto","recoveryKeyReady":False}
                        profile(probe);efi_file(root,relative);paths.append(relative)
        print(json.dumps({"loaders":sorted(paths)}));return
    if action in {"shutdown","force-stop"}:
        if set(request) not in ({"id"},{"id","confirmation"}): raise VmError("The control request is invalid.")
        key=identifier(request["id"]);run,_=locations(uid,key)
        if not active(uid,key): raise VmError("This VM is not running.")
        mode=read_root(run/"request.json")["profile"]["mode"]
        phrase="DISCARD PREVIEW" if mode=="preview" else "FORCE STOP"
        if action=="force-stop" and request.get("confirmation")!=phrase: raise VmError("Type "+phrase+" before ending the VM without guest shutdown.")
        qmp(run/"guest/qmp.sock","quit" if action=="force-stop" else "system_powerdown")
        print(json.dumps({"requested":True}));return
    expected={"profile"} if action=="preflight" else {"profile","wayland","digest","writeConfirmed","shutdownConfirmed"}
    if action not in {"preflight","launch"} or set(request)!=expected: raise VmError("The VM request has unsupported fields.")
    plan=collect(request["profile"]);validate_efi(plan)
    if action=="preflight": print(json.dumps({"plan":plan}));return
    if Path("/run/archiso").exists(): raise VmError("Install Forynarch before starting an existing-OS virtual machine.")
    if plan["digest"]!=request["digest"]: raise VmError("The reviewed VM plan changed. Review it again.")
    if request["shutdownConfirmed"] is not True: raise VmError("Confirm that the other operating system was fully shut down.")
    if plan["profile"]["mode"]=="direct" and request["writeConfirmed"] is not True: raise VmError("Confirm direct writes to the selected OS volume.")
    desktop_environment(uid,request["wayland"])
    ensure_kvm()
    key=plan["profile"]["id"];run,_=locations(uid,key)
    with open(run/"launch.lock","w") as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        if active(uid,key): raise VmError("This VM is already running.")
        atomic(run/"request.json",{"profile":plan["profile"],"digest":plan["digest"],"wayland":request["wayland"]})
        atomic(run/"state.json",{"id":key,"phase":"starting","error":""},account.pw_gid,True)
        command(["systemd-run","--unit="+unit_name(uid,key),"--collect","--property=Type=exec","--property=KillMode=mixed","--property=TimeoutStopSec=150","--property=UMask=0077",
                 f"--property=ExecStopPost={PROGRAM} cleanup {uid} {key}","--",PROGRAM,"run",str(uid),key])
    print(json.dumps({"started":True,"id":key}))


if __name__=="__main__":
    try:main()
    except (VmError,OSError,ValueError,KeyError,subprocess.SubprocessError) as error:
        print(json.dumps({"error":str(error) if isinstance(error,VmError) else "The virtual-machine operation failed."}),file=sys.stderr)
        sys.exit(1)
