#!/usr/bin/env python3
"""Per-user experimental VM settings and authenticated operations."""
import fcntl
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import uuid

sys.path.insert(0, "/usr/local/lib/forynarch")
from forynarch_vm import MIB, SUPPORT_PACKAGES, VmError, flatten, identifier, profile

SERVICE = "/usr/local/libexec/forynarch-vm-service"
REQUIRED = ("qemu-system-x86_64", "qemu-img", "swtpm", "dmsetup", "losetup", "mkfs.fat", "mcopy", "mmd", "ntfs-3g.probe", "ntfsls")


def config_path():
    return Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home()/".config"))) / "forynarch/virtual-machines.json"


def document():
    path=config_path()
    if not path.exists(): return {"version":1,"enabled":False,"profiles":[]}
    if path.stat().st_size>65536: raise VmError("The virtual-machine configuration is too large.")
    data=json.loads(path.read_text())
    if not isinstance(data,dict) or set(data)!={"version","enabled","profiles"} or data["version"]!=1 or type(data["enabled"]) is not bool or not isinstance(data["profiles"],list) or len(data["profiles"])>8:
        raise VmError("The virtual-machine configuration is invalid.")
    data["profiles"]=[profile(p) for p in data["profiles"]]
    if len({p["id"] for p in data["profiles"]})!=len(data["profiles"]): raise VmError("VM profile identities must be unique.")
    return data


def save(data):
    path=config_path();path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    fd,temporary=tempfile.mkstemp(prefix=".vm-",dir=path.parent)
    try:
        with os.fdopen(fd,"w") as stream:json.dump(data,stream);stream.flush();os.fsync(stream.fileno())
        os.replace(temporary,path)
    finally:
        if os.path.exists(temporary):os.unlink(temporary)


def unit(key):
    return f"forynarch-vm-{os.getuid()}-{identifier(key).replace('-','')}.service"


def vm_state(key):
    status={"id":key,"phase":"stopped","error":""}
    path=Path("/run/forynarch-vm")/str(os.getuid())/identifier(key)/"state.json"
    try:
        info=path.lstat()
        if stat.S_ISREG(info.st_mode) and info.st_uid==0 and info.st_size<16384:
            data=json.loads(path.read_text())
            if data.get("id")==key:status.update({k:data[k] for k in ("phase","error") if isinstance(data.get(k),str)})
    except (OSError,ValueError):pass
    try:
        active=subprocess.run(["systemctl","show","--property=ActiveState","--value",unit(key)],capture_output=True,text=True,timeout=3).stdout.strip()
        running=active in {"active","activating","deactivating","reloading"}
    except (OSError,subprocess.SubprocessError):running=False
    if not running and status["phase"] not in {"error","cleanup-required"}:status["phase"]="stopped"
    status["active"]=running or status["phase"]=="cleanup-required"
    return status


def discover():
    result=subprocess.run(["lsblk","--json","--bytes","--output","NAME,PATH,TYPE,SIZE,FSTYPE,LABEL,PARTUUID,PARTTYPE,MOUNTPOINTS,RO"],text=True,capture_output=True,timeout=8,check=True)
    return [row for row in flatten(json.loads(result.stdout)["blockdevices"]) if row.get("type")=="part" and row.get("partuuid")]


def managed_states(data):
    keys={p["id"] for p in data["profiles"]}
    root=Path("/run/forynarch-vm")/str(os.getuid())
    if root.is_dir():
        for path in root.iterdir():
            try:keys.add(identifier(path.name))
            except VmError:continue
    return [vm_state(key) for key in sorted(keys)]


def status(data):
    memory={key:int(value.split()[0])*1024 for key,value in (line.split(":",1) for line in Path("/proc/meminfo").read_text().splitlines())}
    states=managed_states(data)
    return {**data,"states":states,"missing":[p for p in REQUIRED if not shutil.which(p)],"packages":list(SUPPORT_PACKAGES),
            "live":Path("/run/archiso").exists(),"kvm":Path("/dev/kvm").exists(),"cpus":os.cpu_count() or 1,
            "availableMiB":memory["MemAvailable"]//MIB,"totalMiB":memory["MemTotal"]//MIB,"devices":discover()}


def authorize(action, request=None, timeout=120):
    result=subprocess.run(["pkexec",SERVICE,action],input=json.dumps(request or {}),capture_output=True,text=True,timeout=timeout)
    if result.returncode:
        try:message=json.loads(result.stderr.strip()).get("error","")
        except ValueError:message="System authentication was cancelled or the operation failed."
        raise VmError(message or "The virtualization operation was not authorized.")
    try:return json.loads(result.stdout)
    except ValueError:raise VmError("The virtualization helper returned an invalid response.") from None


def main():
    if os.geteuid()==0: raise VmError("Open virtual-machine settings as your desktop user.")
    action=sys.argv[1] if len(sys.argv)>1 else "status"
    if action not in {"status","new","enable","save","remove","loaders","preflight","launch","shutdown","force-stop","recover","support-install"}:raise VmError("Choose a supported virtual-machine action.")
    if len(sys.argv)>2:raise VmError("Send VM settings on standard input.")
    if action=="status":print(json.dumps(status(document())));return
    if action=="new":
  print(json.dumps({"profile":{"id":str(uuid.uuid4()),"name":"Windows","osPartuuid":"","efiPartuuid":"","efiPath":"EFI/Microsoft/Boot/bootmgfw.efi","family":"windows","mode":"preview","memoryMiB":4096,"cpus":min(2,max(1,(os.cpu_count() or 1)-1)),"controller":"auto","recoveryKeyReady":False,"network":True,"audio":True}}));return
    path=config_path();path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    with open(path.with_suffix(".lock"),"w") as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        data=document()
        if action=="status":result=status(data)
        else:
            raw=sys.stdin.buffer.read(65537)
            if len(raw)>65536:raise VmError("The VM request is too large.")
            request=json.loads(raw or b"{}")
            if not isinstance(request,dict):raise VmError("The VM request is invalid.")
            if action=="enable":
                if set(request)!={"enabled"} or type(request["enabled"]) is not bool:raise VmError("Choose whether to enable experimental VMs.")
                if not request["enabled"] and any(s["active"] for s in managed_states(data)):raise VmError("Shut down running VMs and release their resources before disabling this feature.")
                data["enabled"]=request["enabled"];save(data);result=status(data)
            elif action=="save":
                if set(request)!={"profile"}:raise VmError("Choose a complete VM profile.")
                selected=profile(request["profile"])
                if vm_state(selected["id"])["active"]:raise VmError("Shut down this VM before editing its profile.")
                others=[p for p in data["profiles"] if p["id"]!=selected["id"]]
                if len(others)>=8:raise VmError("At most eight VM profiles are supported.")
                data["profiles"]=others+[selected];save(data);result=status(data)
            elif action=="remove":
                if set(request)!={"id","deleteConfirmed"} or request["deleteConfirmed"] is not True:raise VmError("Confirm removal of this VM's private EFI, firmware and TPM data.")
                key=identifier(request["id"])
                if vm_state(key)["active"]:raise VmError("Shut down this VM before removing its profile.")
                authorize("forget",{"id":key,"deleteConfirmed":True})
                data["profiles"]=[p for p in data["profiles"] if p["id"]!=key];save(data);result=status(data)
            elif action=="support-install":
                if request!={"updateConfirmed":True}:raise VmError("Confirm installation of VM support and the system update.")
                result=authorize(action,timeout=3600)
            elif action=="loaders":result=authorize(action,request)
            else:
                if not data["enabled"] and action not in {"shutdown","force-stop","recover"}:raise VmError("Enable experimental virtual machines first.")
                key=identifier(request.get("id",""))
                selected=next((p for p in data["profiles"] if p["id"]==key),None)
                if selected is None and action not in {"shutdown","force-stop","recover"}:raise VmError("Select a saved VM profile.")
                if action=="preflight":result=authorize(action,{"profile":selected})
                elif action=="launch":
                    if set(request)!={"id","digest","writeConfirmed","shutdownConfirmed"}:raise VmError("Review the VM before launching it.")
                    result=authorize(action,{"profile":selected,"wayland":os.environ.get("WAYLAND_DISPLAY",""),**{k:request[k] for k in ("digest","writeConfirmed","shutdownConfirmed")}})
                else:result=authorize(action,request)
        print(json.dumps(result))


if __name__=="__main__":
    try:main()
    except (VmError,OSError,ValueError,KeyError,subprocess.SubprocessError) as error:
        print(json.dumps({"error":str(error) if isinstance(error,VmError) else "Virtual-machine settings could not complete this operation."}),file=sys.stderr)
        sys.exit(1)
