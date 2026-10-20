"""Root-only disposable block-device QA inside the project Arch builder."""
import contextlib
import errno
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import time
import uuid

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"scripts"))
import forynarch_vm as model
spec=importlib.util.spec_from_file_location("vm_service",ROOT/"scripts/forynarch-vm-service.py")
service=importlib.util.module_from_spec(spec);spec.loader.exec_module(service)


def run(*args,**kwargs):
    return subprocess.run(args,check=True,text=True,capture_output=True,**kwargs).stdout.strip()


def digest(path):
    h=hashlib.sha256()
    with open(path,"rb",buffering=0) as stream:
        for block in iter(lambda:stream.read(1024*1024),b""):h.update(block)
    return h.hexdigest()


def qmp(socket_path, action, arguments=None):
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(5);connection.connect(str(socket_path));stream=connection.makefile("rwb")
        json.loads(stream.readline())
        def exchange(value):
            stream.write(json.dumps(value).encode()+b"\n");stream.flush()
            while True:
                data=json.loads(stream.readline())
                if "event" not in data:
                    assert "error" not in data,data
                    return data.get("return")
        exchange({"execute":"qmp_capabilities"})
        return exchange({"execute":action,**({"arguments":arguments} if arguments else {})})


def runner(key, graphical=False):
    # The small EFI fixture cannot consume a Windows-sized preview budget.
    # Resource guard behavior is tested separately; no production hook is added.
    original=service.shutil.disk_usage
    service.shutil.disk_usage=lambda _:original("/")._replace(free=16*1024**3)
    service.run_guest(1000,key,software=True,headless=not graphical)


def guest_processes(runtime):
    result={}
    for path in Path("/proc").iterdir():
        if not path.name.isdecimal():continue
        try:
            arguments=(path/"cmdline").read_bytes()
            if str(runtime/"guest/qmp.sock").encode() in arguments:kind="qemu"
            elif str(runtime/"guest/tpm.sock").encode() in arguments:kind="tpm"
            else:continue
            status=(path/"status").read_text()
            identities=next(line.split()[1:] for line in status.splitlines() if line.startswith("Uid:"))
            assert identities==["1000"]*4,(kind,identities)
            assert int(next(line.split()[1] for line in status.splitlines() if line.startswith("CapEff:")),16)==0
            result[kind]=int(path.name)
        except FileNotFoundError:continue
    assert set(result)=={"qemu","tpm"},result
    return result


def main():
    assert os.geteuid()==0
    expected_uuid=os.environ.get("FORYNARCH_QA_SCRATCH_UUID", "")
    assert expected_uuid and run("findmnt","-nro","UUID","/mnt/forynarch-build")==expected_uuid
    if len(sys.argv) in {3,4} and sys.argv[1]=="runner":runner(model.identifier(sys.argv[2]),len(sys.argv)==4 and sys.argv[3]=="gtk");return
    if len(sys.argv)==3 and sys.argv[1]=="cleanup":
        key=model.identifier(sys.argv[2]);sys.argv=[service.PROGRAM,"cleanup","1000",key];service.main();return
    temporary=Path(tempfile.mkdtemp(prefix="os-vm-fixture-",dir="/mnt/forynarch-build"))
    disk=temporary/"source.img";loop=None;mounted=False;guest=None;key=str(uuid.uuid4())
    efi_uuid,os_uuid,host_uuid=[str(uuid.uuid4()) for _ in range(3)]
    host_mount=temporary/"host";host_mount.mkdir()
    try:
        with disk.open("wb") as stream:stream.truncate(256*1024**2)
        loop=run("losetup","--find","--show","--partscan",str(disk))
        backing=json.loads(run("losetup","--list","--json","--output","NAME,BACK-FILE",loop))["loopdevices"][0]["back-file"]
        assert Path(backing)==disk and disk.resolve().is_relative_to(temporary.resolve())
        layout=f"label: gpt\nunit: sectors\nstart=2048,size=131072,type={model.ESP_TYPE},uuid={efi_uuid}\nstart=133120,size=262144,type=ebd0a0a2-b9e5-4433-87c0-68b6b72699c7,uuid={os_uuid}\nstart=395264,size=65536,type=0fc63daf-8483-4772-8e79-3d69d8477de4,uuid={host_uuid}\n"
        run("sfdisk",loop,input=layout)
        run("udevadm","settle")
        efi,os_volume,host=[loop+"p"+str(n) for n in (1,2,3)]
        run("mkfs.fat","-F","32",efi)
        run("mkntfs","-Q","-F","-L","VM_FIXTURE",os_volume)
        run("mkfs.ext4","-q","-F","-E","lazy_itable_init=0,lazy_journal_init=0",host)
        run("mount","-o","noatime",host,str(host_mount));mounted=True
        (host_mount/"host-sentinel.txt").write_text("This host-only fixture data must never be visible to the guest.")
        run("sync","-f",str(host_mount))
        shell=Path("/usr/share/edk2-shell/x64/Shell.efi")
        if not shell.exists():shell=next(Path("/usr/share/edk2-shell").rglob("Shell*.efi"))
        run("mmd","-i",efi,"::/EFI","::/EFI/BOOT")
        run("mcopy","-i",efi,str(shell),"::/EFI/BOOT/BOOTX64.EFI")
        secret=temporary/"host-only.efi";secret.write_bytes(b"HOST_EFI_CONTENT_MUST_NOT_BE_COPIED")
        run("mmd","-i",efi,"::/EFI/Forynarch")
        run("mcopy","-i",efi,str(secret),"::/EFI/Forynarch/host-only.efi")
        run("udevadm","trigger","--action=change",f"/sys/class/block/{Path(efi).name}",f"/sys/class/block/{Path(os_volume).name}")
        run("udevadm","settle")
        p={"id":key,"name":"EFI fixture","osPartuuid":os_uuid,"efiPartuuid":efi_uuid,"efiPath":"EFI/BOOT/BOOTX64.EFI","family":"other","mode":"preview","memoryMiB":512,"cpus":1,"controller":"sata","recoveryKeyReady":False}
        plan=service.collect(p);service.validate_efi(plan)
        assert plan["source"]["path"]==os_volume
        before={"os":digest(os_volume),"efi":digest(efi),"host":digest(host)}
        header_fd=os.open(loop,os.O_RDONLY)
        original_header=os.pread(header_fd,1024*1024,0)
        os.close(header_fd)
        runtime,store=service.locations(1000,key)
        service.prepare_images(plan,store)
        assert subprocess.run(["mdir","-i",str(store/"efi.img"),"::/EFI/Forynarch"],capture_output=True).returncode!=0
        baseline=os.open(os_volume,os.O_RDONLY|os.O_EXCL);os.close(baseline)
        view=service.create_mapping(plan,1000,key)
        try:
            try:exclusive=os.open(os_volume,os.O_RDONLY|os.O_EXCL)
            except OSError as error:assert error.errno==errno.EBUSY,error
            else:os.close(exclusive);raise AssertionError("The source was not exclusively claimed")
            fd=os.open(view,os.O_RDONLY)
            try:
                assert os.pread(fd,8,512)==b"EFI PART"
                try:os.pread(fd,512,395264*512)
                except OSError as error:assert error.errno==errno.EIO,error
                else:raise AssertionError("The host partition was exposed")
            finally:os.close(fd)
            overlay=store/"preview.qcow2"
            run("qemu-img","create","-f","qcow2","-F","raw","-b",str(view),str(overlay))
            run("qemu-io","-f","qcow2","-c",f"write -P 0x5a {plan['osStart']*512+8*1024**2} 4096",str(overlay))
            assert digest(os_volume)==before["os"]
        finally:service.cleanup(1000,key)
        baseline=os.open(os_volume,os.O_RDONLY|os.O_EXCL);os.close(baseline)
        print("PREVIEW_SOURCE_UNCHANGED_HOST_MASKED_EXCLUSIVE_CLAIM_OK",flush=True)
        desktop=os.environ.get("FORYNARCH_FIXTURE_WAYLAND","")
        service.atomic(runtime/"request.json",{"profile":p,"digest":plan["digest"],"wayland":desktop})
        guest=subprocess.Popen([sys.executable,__file__,"runner",key,*(["gtk"] if desktop else [])],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        state={}
        for _ in range(240):
            if guest.poll() is not None:
                out,err=guest.communicate();log=(store/"qemu.log").read_text() if (store/"qemu.log").exists() else ""
                raise AssertionError((out,err,log))
            if (runtime/"state.json").exists():state=json.loads((runtime/"state.json").read_text())
            if state.get("phase")=="running" and (runtime/"guest/qmp.sock").exists():break
            time.sleep(.25)
        else:raise AssertionError(state)
        # TCG is intentional in this nested VirtualBox fixture; no production fallback.
        time.sleep(10)
        if guest.poll() is not None:
            out,err=guest.communicate();raise AssertionError((out,err,(store/"qemu.log").read_text()))
        processes=guest_processes(runtime)
        mapped_number=os.stat(Path("/dev/mapper")/service.managed_name(1000,key)).st_rdev
        for descriptor in (Path("/proc")/str(processes["qemu"])/"fd").iterdir():
            with contextlib.suppress(FileNotFoundError):
                info=descriptor.stat()
                if __import__("stat").S_ISBLK(info.st_mode):assert info.st_rdev==mapped_number,"A physical source descriptor leaked into QEMU"
        result=qmp(runtime/"guest/qmp.sock","query-status");assert result["running"],result
        if desktop:
            environment=["runuser","-u","builder","--","env","XDG_RUNTIME_DIR=/run/user/1000",f"WAYLAND_DISPLAY={desktop}"]
            scene=subprocess.run([*environment,"timeout","2","weston-debug","scene-graph"],capture_output=True,text=True)
            (temporary/"wayland-scene.txt").write_text(scene.stdout)
            assert f"PID {processes['qemu']}" in scene.stdout,scene.stdout
            clients=run(*environment,"pw-cli","ls","Client")
            assert "qemu" in clients.lower(),clients
            print("QEMU_GTK_WAYLAND_WINDOW_AND_PIPEWIRE_CLIENT_OK",flush=True)
        screenshot=runtime/"guest/uefi-fixture.png"
        qmp(runtime/"guest/qmp.sock","screendump",{"filename":str(screenshot),"format":"png"})
        output=ROOT/"out/virtualbox/os-vm-uefi-fixture.png";output.parent.mkdir(parents=True,exist_ok=True)
        output.write_bytes(screenshot.read_bytes())
        qmp(runtime/"guest/qmp.sock","quit")
        out,err=guest.communicate(timeout=30);assert guest.returncode==0,(out,err)
        guest=None
        assert digest(os_volume)==before["os"]
        assert not (store/"preview.qcow2").exists()
        assert not (runtime/"resources.json").exists()
        print("QEMU_UNPRIVILEGED_OVMF_PREVIEW_EXIT_AND_CLEANUP_OK",flush=True)
        unit=service.unit_name(1000,key)
        run("systemd-run","--unit="+unit,"--collect","--property=Type=exec","--property=KillMode=mixed","--property=TimeoutStopSec=15",
            f"--property=ExecStopPost={sys.executable} {__file__} cleanup {key}","--",sys.executable,__file__,"runner",key)
        for _ in range(240):
            current=json.loads((runtime/"state.json").read_text())
            if current.get("phase")=="running" and service.active(1000,key):break
            time.sleep(.25)
        else:raise AssertionError(current)
        root_pid=int(run("systemctl","show","--property=MainPID","--value",unit));assert root_pid>1
        os.kill(root_pid,signal.SIGKILL)
        for _ in range(160):
            if not service.active(1000,key):break
            time.sleep(.25)
        else:raise AssertionError("The VM supervisor did not stop")
        assert not (runtime/"resources.json").exists()
        assert digest(os_volume)==before["os"]
        assert json.loads((runtime/"state.json").read_text())["phase"]=="error"
        print("SUPERVISOR_CRASH_CGROUP_AND_EXECSTOPPOST_CLEANUP_OK",flush=True)
        p["mode"]="direct";plan=service.collect(p);service.prepare_images(plan,store)
        view=service.create_mapping(plan,1000,key)
        fd=os.open(view,os.O_RDWR)
        marker=b"FORYNARCH_DIRECT_FIXTURE_ONLY".ljust(512,b".")
        try:os.pwrite(fd,marker,plan["osStart"]*512+8*1024**2);os.fsync(fd)
        finally:os.close(fd);service.cleanup(1000,key)
        source_fd=os.open(os_volume,os.O_RDONLY)
        try:assert os.pread(source_fd,512,8*1024**2)==marker
        finally:os.close(source_fd)
        header_fd=os.open(loop,os.O_RDONLY)
        try:assert os.pread(header_fd,1024*1024,0)==original_header
        finally:os.close(header_fd)
        assert digest(efi)==before["efi"] and digest(host)==before["host"]
        assert (host_mount/"host-sentinel.txt").read_text().startswith("This host-only")
        print("DIRECT_WRITES_ONLY_SELECTED_FIXTURE_PARTITION_OK",flush=True)
        service.forget(1000,key)
    finally:
        if guest and guest.poll() is None:
            guest.terminate()
            try:guest.wait(timeout=20)
            except subprocess.TimeoutExpired:guest.kill();guest.wait()
        with contextlib.suppress(Exception):service.cleanup(1000,key)
        if mounted:run("umount",str(host_mount))
        if loop:run("losetup","--detach",loop)
        # Keep failed fixtures for inspection; no broad deletion or loop reset.


if __name__=="__main__":main()
