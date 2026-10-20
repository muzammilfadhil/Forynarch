"""Validate prepared root/ESP assignments without modifying any block device."""
import json
from pathlib import Path
import re
import subprocess
import sys

ESP="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
LINUX_ROOT_TYPES={"0fc63daf-8483-4772-8e79-3d69d8477de4","4f68bce3-e8cd-4db1-96e7-fbcaf984b709"}
UUID=re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")
DRIVER_PACKAGES={"intel-vulkan":["vulkan-intel"],"amd-vulkan":["vulkan-radeon"]}

def driver_packages(selected,inventory,catalog,offline=False):
    if not isinstance(selected,list) or any(not isinstance(value,str) for value in selected):
        raise ValueError("Invalid driver selection.")
    if selected and offline:raise ValueError("Optional graphics drivers require an online installation.")
    choices={choice["id"]:choice for choice in catalog["choices"]}
    packages=[]
    for identifier in sorted(set(selected)):
        choice=choices.get(identifier)
        if not choice or choice.get("blocked") or identifier not in DRIVER_PACKAGES:
            raise ValueError("This driver is not available for automatic installation.")
        if choice.get("packages")!=DRIVER_PACKAGES[identifier]:raise ValueError("The driver catalogue does not match this installer.")
        if not any(gpu.get("vendor")==choice["vendor"] for gpu in inventory.get("graphics",[])):
            raise ValueError("The selected driver does not match detected hardware.")
        packages.extend(choice["packages"])
    return sorted(set(packages))

def prepared_layout(plan,inventory):
    if plan.get("kind") not in ("install-manual","install-alongside"):raise ValueError("Choose prepared-partition installation.")
    if not inventory.get("live") or not inventory.get("uefi"):raise ValueError("Boot the Live media in UEFI mode to install prepared partitions.")
    if plan.get("revision")!=inventory.get("revision"):raise ValueError("Disk information changed. Refresh and review again.")
    matches=[d for d in inventory.get("disks",[]) if d["id"]==plan.get("diskId")]
    if len(matches)!=1:raise ValueError("Select a detected disk.")
    disk=matches[0]
    if not disk.get("stableIdentity") or disk.get("readOnly") or disk.get("containsSystem"):
        raise ValueError("The selected disk is protected, read-only, or has no stable identity.")
    if disk.get("table")!="gpt":raise ValueError("The selected disk was not detected as GPT. Refresh disks after applying changes in Partition Manager.")
    if not disk.get("geometryKnown"):raise ValueError("Partition boundaries could not be verified. Check the partition table in Partition Manager; this is separate from its GPT type.")
    def partition(key):
        matches=[p for p in disk.get("partitions",[]) if p["id"]==plan.get(key)]
        if len(matches)!=1:raise ValueError("Choose the root and EFI partitions from this disk.")
        part=matches[0];uuid=part.get("partitionUuid","")
        if not UUID.fullmatch(uuid) or part["id"]!="partuuid:"+uuid:
            raise ValueError("Each selected partition needs a valid GPT partition UUID.")
        if part.get("mounted") or part.get("readOnly") or part.get("encrypted"):
            raise ValueError("Unmount the selected partitions. Encrypted and read-only partitions cannot be assigned.")
        return part
    root=partition("rootPartitionId");efi=partition("efiPartitionId")
    if root["id"]==efi["id"]:raise ValueError("Root and EFI must be different partitions.")
    if root.get("protected") or root.get("partitionType") not in LINUX_ROOT_TYPES or str(root.get("filesystem","")).lower() not in ("","unknown","ext4","btrfs","xfs"):
        raise ValueError("Choose an empty or Linux root partition. EFI, recovery, reserved and Windows/data volumes cannot be formatted here.")
    if root["size"]<32*1024**3:raise ValueError("The root partition needs at least 32 GiB.")
    if efi.get("partitionType")!=ESP or str(efi.get("filesystem","")).lower() not in ("vfat","fat32","fat") or efi["size"]<100*1024**2:
        raise ValueError("Choose an existing FAT32 EFI System Partition of at least 100 MiB. It will be preserved.")
    register=plan.get("registerBootEntry",False)
    if type(register) is not bool:raise ValueError("Invalid firmware boot-entry selection.")
    return {"root":root,"efi":efi,"registerBootEntry":register,
        "summary":"Format only "+root["path"]+" as ext4; preserve "+efi["path"]+" and all other partitions. Existing Forynarch boot files are backed up before replacement; other EFI loaders are kept. Kernel files stay on the Linux root; the EFI partition is mounted at /efi."}

def installation_review(plan,inventory,review):
    if plan.get("kind") not in ("install-manual","install-alongside"):return review
    try:layout=prepared_layout(plan,inventory)
    except ValueError as error:
        return dict(review,canExecute=False,reviewOnly=True,blockers=list(review.get("blockers",[]))+[str(error)])
    blockers=list(review.get("blockers",[]))
    if not inventory.get("executorAvailable"):blockers.append("The matching installation payload is unavailable.")
    if plan.get("filesystem")!="ext4":blockers.append("Prepared-partition installation currently uses ext4 for root.")
    return dict(review,layout=layout,summary=layout["summary"],destructive=True,blockers=blockers,canExecute=not blockers,reviewOnly=bool(blockers))

def inspect_device_assignments(inventory,disk_path,root_path,efi_path,register):
    disk=next((d for d in inventory["disks"] if d["path"]==disk_path),None)
    if not disk:raise ValueError("The target disk disappeared.")
    def selected(path):
        if not re.fullmatch(r"/dev/disk/by-partuuid/[0-9a-f-]+",path):raise ValueError("Use stable /dev/disk/by-partuuid partition paths.")
        resolved=str(Path(path).resolve(strict=True))
        return next((p["id"] for p in disk["partitions"] if p["path"]==resolved and p["id"]=="partuuid:"+Path(path).name),"")
    plan={"kind":"install-manual","revision":inventory["revision"],"diskId":disk["id"],
        "rootPartitionId":selected(root_path),"efiPartitionId":selected(efi_path),"registerBootEntry":register}
    result=prepared_layout(plan,inventory)
    for part,allowed in ((result["root"],{"","ext4","btrfs","xfs"}),(result["efi"],{"vfat"})):
        probe=subprocess.run(["blkid","-p","-s","TYPE","-o","value",part["path"]],capture_output=True,text=True,timeout=10)
        if probe.returncode not in (0,2) or probe.stderr.strip() or probe.stdout.strip() not in allowed:
            raise ValueError("The partition signature is encrypted, unsupported, or could not be verified. Return to Partition Manager.")
    return result

def boot_entries(esp,uuid):
    if not re.fullmatch(r"[0-9a-fA-F-]{4,64}",uuid):raise ValueError("Invalid EFI filesystem UUID")
    folder=Path(esp)/"EFI";entries=[]
    for vendor in sorted(folder.iterdir() if folder.is_dir() else []):
        if not vendor.is_dir() or vendor.is_symlink() or vendor.name.lower() in ("boot","forynarch") or vendor.name.lower().startswith("forynarch-backup-") or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,63}",vendor.name):continue
        paths=["Boot/bootmgfw.efi"] if vendor.name.lower()=="microsoft" else ["grubx64.efi","shimx64.efi","systemd-bootx64.efi"]
        loader=next((name for name in paths if (vendor/name).is_file() and not (vendor/name).is_symlink()),None)
        if not loader:continue
        title="Windows Boot Manager" if vendor.name.lower()=="microsoft" else "Existing EFI system: "+vendor.name
        entries.append("menuentry '"+title+"' {\n  insmod part_gpt\n  insmod fat\n  insmod chain\n  search --no-floppy --fs-uuid --set=existing_efi "+uuid+"\n  chainloader ($existing_efi)/EFI/"+vendor.name+"/"+loader+"\n}\n")
    return "\n".join(entries)

if __name__=="__main__":
    try:
        if sys.argv[1:]==["review"]:
            data=json.load(sys.stdin);result=installation_review(data["plan"],data["inventory"],data["review"])
        elif len(sys.argv)==6 and sys.argv[1]=="inspect":
            result=inspect_device_assignments(json.load(sys.stdin),*sys.argv[2:5],sys.argv[5]=="true")
        elif len(sys.argv)>=4 and sys.argv[1]=="drivers":
            inventory=json.load(sys.stdin)
            catalog=json.loads(Path(sys.argv[2]).read_text())
            print("\n".join(driver_packages(sys.argv[4:],inventory,catalog,sys.argv[3]=="true")));raise SystemExit(0)
        elif len(sys.argv)==4 and sys.argv[1]=="boot-entries":
            print(boot_entries(sys.argv[2],sys.argv[3]));raise SystemExit(0)
        else:raise ValueError("Invalid installation layout action.")
        print(json.dumps(result))
    except (OSError,ValueError,KeyError,TypeError) as error:
        print(str(error),file=sys.stderr);raise SystemExit(1)
