#!/usr/bin/env python3
"""Data-only protocol fixture; never imports or calls the privileged helper."""
import json
import fcntl
import os
from pathlib import Path
import sys

path=Path(os.environ["FORYNARCH_VM_TEST_STATE"])
lock=open(str(path)+".lock","w");fcntl.flock(lock,fcntl.LOCK_EX)
p={"id":"11111111-1111-4111-8111-111111111111","name":"Windows fixture","osPartuuid":"22222222-2222-4222-8222-222222222222","efiPartuuid":"33333333-3333-4333-8333-333333333333","efiPath":"EFI/Microsoft/Boot/bootmgfw.efi","family":"windows","mode":"preview","memoryMiB":4096,"cpus":2,"controller":"auto","recoveryKeyReady":False}
state=json.loads(path.read_text()) if path.exists() else {"version":1,"enabled":False,"profiles":[],"states":[],"history":[]}
action=sys.argv[1];request=json.loads(sys.stdin.read() or "{}") if action not in {"status","new"} else {}
state["history"].append(action)
source={"path":"/dev/nvme9n9p3","type":"part","partuuid":p["osPartuuid"],"size":128*1024**3,"fstype":"ntfs","mountpoints":[],"label":"Windows"}
efi={"path":"/dev/nvme9n9p1","type":"part","partuuid":p["efiPartuuid"],"parttype":"c12a7328-f81f-11d2-ba4b-00a0c93ec93b","size":256*1024**2,"fstype":"vfat","mountpoints":["/boot"]}
def status():return {**state,"missing":[],"packages":[],"live":False,"kvm":True,"cpus":4,"availableMiB":12288,"devices":[source,efi]}
if action=="enable":state["enabled"]=request["enabled"];result=status()
elif action=="new":result={"profile":p}
elif action=="save":state["profiles"]=[request["profile"]];result=status()
elif action=="preflight":result={"plan":{"profile":state["profiles"][0],"digest":"a"*64,"source":source}}
elif action=="launch":
    assert request["digest"]=="a"*64 and request["shutdownConfirmed"] and request["writeConfirmed"]
    state["states"]=[{"id":p["id"],"phase":"running","active":True,"error":""}];result={"started":True}
elif action=="status":result=status()
else:raise ValueError("Unexpected fixture action")
path.write_text(json.dumps(state));print(json.dumps(result))
