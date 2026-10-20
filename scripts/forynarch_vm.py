"""Validated existing-OS VM plans and private GPT views; no device writes."""
import hashlib
import json
import re
import struct
import uuid
import zlib

ESP_TYPE = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
SUPPORT_PACKAGES = ("qemu-desktop", "edk2-ovmf", "swtpm", "device-mapper", "mtools", "dosfstools", "ntfs-3g", "ntfsprogs")
FIELDS = {"id", "name", "osPartuuid", "efiPartuuid", "efiPath", "family", "mode", "memoryMiB", "cpus", "controller", "recoveryKeyReady"}
OPTIONAL_FIELDS = {"network", "audio"}
MIB = 1024 * 1024


class VmError(ValueError):
    pass


def identifier(value):
    try:
        if not isinstance(value, str) or str(uuid.UUID(value)) != value:
            raise ValueError()
    except (ValueError, AttributeError):
        raise VmError("A valid partition or profile identity is required.") from None
    return value


def profile(document):
    if not isinstance(document, dict) or not FIELDS <= set(document) or set(document) - FIELDS - OPTIONAL_FIELDS:
        raise VmError("The VM profile has unsupported fields.")
    result = dict(document)
    for key in OPTIONAL_FIELDS:
        result.setdefault(key, True)
        if type(result[key]) is not bool:
            raise VmError("Guest network and audio choices must be on or off.")
    for key in ("id", "osPartuuid", "efiPartuuid"):
        identifier(result[key])
    if result["osPartuuid"] == result["efiPartuuid"]:
        raise VmError("Select separate operating-system and EFI partitions.")
    name = result["name"]
    if not isinstance(name, str) or not 1 <= len(name.strip()) <= 64 or any(ord(c) < 32 for c in name):
        raise VmError("Use a VM name of 1–64 characters without control characters.")
    result["name"] = name.strip()
    path = result["efiPath"]
    if not isinstance(path, str) or not re.fullmatch(r"EFI/[A-Za-z0-9_. -]+(?:/[A-Za-z0-9_. -]+){1,6}\.efi", path, re.I) or any(p in {".", ".."} for p in path.split("/")):
        raise VmError("Choose an EFI executable below the EFI folder.")
    if result["family"] not in {"windows", "other"} or result["mode"] not in {"preview", "direct"} or result["controller"] not in {"auto", "nvme", "sata"}:
        raise VmError("Select a supported guest, disk mode and controller.")
    if path.split("/")[1].lower()=="forynarch" or (result["family"]=="windows" and not path.lower().startswith("efi/microsoft/boot/")):
        raise VmError("Choose the selected OS's EFI loader, rather than Forynarch's boot files.")
    if type(result["memoryMiB"]) is not int or not 512 <= result["memoryMiB"] <= 262144 or result["memoryMiB"] % 256:
        raise VmError("Guest memory must be a multiple of 256 MiB, between 512 MiB and 256 GiB.")
    if result["family"] == "windows" and result["memoryMiB"] < 2048:
        raise VmError("Use at least 2 GiB for Windows; Windows 11 normally needs 4 GiB or more.")
    if type(result["cpus"]) is not int or not 1 <= result["cpus"] <= 128 or type(result["recoveryKeyReady"]) is not bool:
        raise VmError("Select a valid CPU count and recovery-key acknowledgement.")
    return result


def flatten(tree):
    rows = []
    def visit(row, parent=None):
        item = {key: value for key, value in row.items() if key != "children"}
        item["parent"] = parent
        rows.append(item)
        for child in row.get("children", []):
            visit(child, row.get("path"))
    for row in tree:
        visit(row)
    return rows


def select_partition(rows, partuuid, *, efi=False):
    matches = [r for r in rows if str(r.get("partuuid") or "").lower() == partuuid]
    paths = {r.get("path") for r in matches}
    if len(paths) != 1 or not matches:
        raise VmError("The selected partition is missing or has an ambiguous identity. Scan again.")
    row = matches[0]
    if row.get("type") != "part" or not re.fullmatch(r"/dev/[A-Za-z0-9_./-]+", row.get("path", "")):
        raise VmError("Only ordinary GPT partitions are supported in this experiment.")
    if not efi:
        descendants = {row["path"]}
        for _ in rows:
            descendants.update(r["path"] for r in rows if r.get("parent") in descendants)
        if any(any(p for p in r.get("mountpoints", []) or []) or r.get("holders") for r in rows if r.get("path") in descendants):
            raise VmError("The OS volume is mounted, used as swap, or held by another device. Unmount it first.")
    elif str(row.get("parttype") or "").lower() != ESP_TYPE or row.get("fstype") not in {"vfat", "fat", "fat32"}:
        raise VmError("Choose a FAT EFI System Partition.")
    if not efi and row.get("ro"):
        # A physical read-only source is valid for preview, checked by the plan.
        row = dict(row)
    return row


def align(value, unit=MIB):
    return (value + unit - 1) // unit * unit


def make_plan(document, rows, table, *, available_bytes, total_bytes, host_cpus, ntfs_probe=None):
    p = profile(document)
    source = select_partition(rows, p["osPartuuid"])
    efi = select_partition(rows, p["efiPartuuid"], efi=True)
    if table.get("label") != "gpt" or table.get("unit") != "sectors":
        raise VmError("This experiment requires a GPT source disk.")
    sector = table.get("sectorsize", 512)
    if sector not in {512, 4096}:
        raise VmError("The source disk's logical sector size is unsupported.")
    disk = next((r for r in rows if r.get("path") == source.get("parent") and r.get("type") in {"disk", "loop"}), None)
    parts = [r for r in table.get("partitions", []) if str(r.get("uuid", "")).lower() == p["osPartuuid"]]
    if not disk or table.get("device") != disk["path"] or len(parts) != 1 or parts[0].get("node") != source["path"]:
        raise VmError("The partition identity or parent disk changed. Scan again.")
    part = parts[0]
    start, count = part.get("start"), part.get("size")
    disk_bytes = disk.get("size")
    entry_sectors = (128 * 128 + sector - 1) // sector
    if any(type(n) is not int for n in (start, count, disk_bytes)) or start < 2 + entry_sectors or count < 1 or disk_bytes % sector or disk_bytes > 128 * 1024**4:
        raise VmError("The source partition geometry is unsupported.")
    if count * sector != source.get("size") or (start + count) * sector > disk_bytes - (entry_sectors + 1) * sector:
        raise VmError("The source partition bounds do not match the current disk.")
    disk_guid, os_type = identifier(str(table.get("id", "")).lower()), identifier(str(part.get("type", "")).lower())
    suffix = source["path"][len(disk["path"]):].lstrip("p")
    if not suffix.isdecimal() or not 1 <= int(suffix) <= 128:
        raise VmError("The source partition number is unsupported.")
    fs = str(source.get("fstype") or "").lower()
    encrypted = fs in {"bitlocker", "crypto_bitlk"}
    if p["family"] == "windows" and fs not in {"ntfs", "ntfs3", "bitlocker", "crypto_bitlk"}:
        raise VmError("Choose the Windows NTFS or BitLocker system volume.")
    if fs in {"ntfs", "ntfs3"} and ntfs_probe != 0:
        messages = {14:"Windows is hibernated or using Fast Startup. Shut it down completely first.", 15:"The Windows volume is not cleanly unmounted. Shut down Windows normally first.", 16:"The Windows volume is already in use."}
        raise VmError(messages.get(ntfs_probe, "The Windows volume could not be verified as clean. Native shutdown or repair is required."))
    if encrypted and (p["mode"] != "preview" or not p["recoveryKeyReady"]):
        raise VmError("BitLocker is preview-only and requires your recovery key. Forynarch never receives or stores the key.")
    if p["mode"] == "direct" and (fs not in {"ntfs", "ntfs3"} or source.get("ro")):
        raise VmError("Direct mode currently requires clean, writable, unencrypted NTFS.")
    hardware={key:disk.get(key) for key in ("wwn","serial","model","size","maj:min")}
    if p["mode"]=="direct" and disk.get("type")=="disk" and not (disk.get("wwn") or disk.get("serial")):
        raise VmError("A stable disk hardware identity is required for direct writes. Preview remains available.")
    if p["cpus"] > max(1, host_cpus - 1):
        raise VmError("Leave at least one logical CPU for Forynarch.")
    if p["memoryMiB"] * MIB + 768 * MIB > available_bytes or p["memoryMiB"] * MIB + 1536 * MIB > total_bytes:
        raise VmError("There is not enough free memory for this VM while keeping Forynarch responsive.")
    efi_bytes = align(efi.get("size", 0))
    if not 64 * MIB <= efi_bytes <= 2 * 1024**3:
        raise VmError("EFI copying currently supports partitions between 64 MiB and 2 GiB.")
    if sector==4096:efi_bytes=max(efi_bytes,512*MIB)
    efi_start = align(disk_bytes) // sector
    virtual_sectors = efi_start + efi_bytes // sector + MIB // sector
    controller = p["controller"] if p["controller"] != "auto" else ("nvme" if disk["path"].split("/")[-1].startswith("nvme") else "sata")
    visible_fields=("path","type","parent","maj:min","partuuid","uuid","parttype","size","fstype","mountpoints","holders","ro","label")
    source_view={k:source.get(k) for k in visible_fields}
    efi_view={k:efi.get(k) for k in visible_fields}
    result = {"version":1, "profile":p, "source":source_view, "efiSource":efi_view, "diskGuid":disk_guid,
              "diskNumber":disk.get("maj:min"),"hardwareId":hashlib.sha256(json.dumps(hardware,sort_keys=True).encode()).hexdigest(),
              "diskLabel":str(disk.get("model") or "Source disk").strip()+" · "+str(round(disk_bytes/1024**3,1))+" GiB"+(" · ID …"+str(disk["serial"])[-4:] if disk.get("serial") else ""),
              "sectorSize":sector, "osStart":start, "osSectors":count, "osType":os_type,
              "osSlot":int(suffix)-1, "efiStart":efi_start, "efiSectors":efi_bytes//sector,
              "virtualSectors":virtual_sectors, "entrySectors":entry_sectors, "controller":controller}
    # Labels and volatile memory/mount state do not change what is authorized.
    identity = {k:result[k] for k in result if k not in {"source", "efiSource"}}
    identity["devices"] = [{k:r.get(k) for k in ("path", "maj:min", "partuuid", "uuid", "size", "fstype")} for r in (source, efi)]
    result["digest"] = hashlib.sha256(json.dumps(identity, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return result


def private_gpt(plan):
    sector, total, count = plan["sectorSize"], plan["virtualSectors"], plan["entrySectors"]
    entries = bytearray(count * sector)
    def entry(slot, type_id, part_id, first, size, name):
        struct.pack_into("<16s16sQQQ72s", entries, slot*128, uuid.UUID(type_id).bytes_le, uuid.UUID(part_id).bytes_le,
                         first, first+size-1, 0, name.encode("utf-16le").ljust(72, b"\0"))
    entry(plan["osSlot"], plan["osType"], plan["profile"]["osPartuuid"], plan["osStart"], plan["osSectors"], "Existing OS")
    efi_slot = 0 if plan["osSlot"] != 0 else 1
    entry(efi_slot, ESP_TYPE, plan["profile"]["efiPartuuid"], plan["efiStart"], plan["efiSectors"], "Private VM EFI")
    checksum = zlib.crc32(entries[:128*128])
    def header(current, backup, entries_lba):
        data = bytearray(sector)
        struct.pack_into("<8sIIIIQQQQ16sQIII", data, 0, b"EFI PART", 0x10000, 92, 0, 0, current, backup,
                         2+count, total-count-2, uuid.UUID(plan["diskGuid"]).bytes_le, entries_lba, 128, 128, checksum)
        struct.pack_into("<I", data, 16, zlib.crc32(data[:92]))
        return data
    mbr = bytearray(sector)
    struct.pack_into("<B3sB3sII", mbr, 446, 0, b"\0\x02\0", 0xee, b"\xff\xff\xff", 1, min(total-1, 0xffffffff))
    mbr[510:512] = b"\x55\xaa"
    primary = bytes(mbr + header(1, total-1, 2) + entries)
    backup = bytes(entries + header(total-1, 1, total-count-1))
    return primary, backup


def mapper_table(plan, metadata_device, efi_device, os_device, backup_offset=MIB):
    if not all(re.fullmatch(r"[0-9]+:[0-9]+", n) for n in (metadata_device, efi_device, os_device)):
        raise VmError("Invalid managed device identity.")
    factor = plan["sectorSize"] // 512
    spans = [(0, min(MIB//512,plan["osStart"]*factor), metadata_device, 0),
             (plan["osStart"]*factor, plan["osSectors"]*factor, os_device, 0),
             (plan["efiStart"]*factor, plan["efiSectors"]*factor, efi_device, 0),
             (plan["virtualSectors"]*factor-MIB//512, MIB//512, metadata_device, backup_offset//512)]
    lines, position = [], 0
    for start, length, device, offset in sorted(spans):
        if start < position or length < 1:
            raise VmError("Managed disk extents overlap.")
        if start > position:
            lines.append(f"{position} {start-position} error")
        lines.append(f"{start} {length} linear {device} {offset}")
        position = start + length
    if position != plan["virtualSectors"] * factor:
        raise VmError("The managed disk has an invalid final extent.")
    return "\n".join(lines) + "\n"


def qemu_command(plan, firmware, runtime, *, source_fd=3, source_reopen_fds=(), overlay_fd=None, overlay_read_fd=None, variables_fd=5, variables_read_fd=None, software=False, headless=False):
    """Use explicit block graphs; a guest never gets a physical device path."""
    p = plan["profile"]
    args = ["/usr/bin/qemu-system-x86_64", "-nodefaults", "-machine", "q35,accel=" + ("tcg" if software else "kvm"),
            "-cpu", "max" if software else "host", "-m", str(p["memoryMiB"]), "-smp", str(p["cpus"]),
            "-name", "guest=" + p["name"].replace(",", ",,"), "-boot", "menu=on,strict=on",
            "-global", "ICH9-LPC.disable_s3=1", "-global", "ICH9-LPC.disable_s4=1",
            "-rtc", "base=" + ("localtime" if p["family"] == "windows" else "utc"),
            "-qmp", f"unix:{runtime}/qmp.sock,server=on,wait=off", "-monitor", "none",
            "-sandbox", "on,obsolete=deny,elevateprivileges=deny,spawn=" + ("deny" if headless else "allow") + ",resourcecontrol=deny"]
    def block(value):
        args.extend(["-blockdev", json.dumps(value, separators=(",", ":"))])
    def descriptor(number, set_id, additional=()):
        if type(number) is not int or number < 3:
            raise VmError("Invalid inherited device descriptor.")
        args.extend(["-add-fd", f"fd={number},set={set_id}"])
        if len({number,*additional})!=1+len(additional):raise VmError("Inherited descriptors must be distinct.")
        for extra in additional:
            if type(extra) is not int or extra<3:raise VmError("Invalid reopen device descriptor.")
            args.extend(["-add-fd", f"fd={extra},set={set_id}"])
        return f"/dev/fdset/{set_id}"
    preview = p["mode"] == "preview"
    block({"driver":"host_device", "filename":descriptor(source_fd, 1, source_reopen_fds), "node-name":"source-file", "read-only":preview, "cache":{"direct":True,"no-flush":False},"aio":"native"})
    block({"driver":"raw", "file":"source-file", "node-name":"source", "read-only":preview})
    disk = "source"
    if preview:
        if overlay_fd is None:
            raise VmError("Preview requires a private overlay.")
        block({"driver":"file", "filename":descriptor(overlay_fd, 2, (overlay_read_fd,) if overlay_read_fd is not None else ()), "node-name":"overlay-file"})
        block({"driver":"qcow2", "file":"overlay-file", "backing":"source", "node-name":"guest-disk"})
        disk = "guest-disk"
    elif overlay_fd is not None:
        raise VmError("Direct mode cannot accept a preview overlay.")
    args.extend(["-drive", f"if=pflash,format=raw,readonly=on,file={firmware}"])
    args.extend(["-drive", f"if=pflash,format=raw,file={descriptor(variables_fd, 3, (variables_read_fd,) if variables_read_fd is not None else ())}"])
    sector = str(plan["sectorSize"])
    if plan["controller"] == "nvme":
        args.extend(["-device", f"nvme,drive={disk},serial=FORYN{p['id'].replace('-', '')[:15]},bootindex=1,logical_block_size={sector},physical_block_size={sector}"])
    else:
        args.extend(["-device", "ich9-ahci,id=vm-ahci", "-device", f"ide-hd,drive={disk},bus=vm-ahci.0,bootindex=1,logical_block_size={sector},physical_block_size={sector}"])
    args.extend(["-device", "VGA", "-device", "qemu-xhci,id=vm-usb", "-device", "usb-tablet,bus=vm-usb.0",
                 "-chardev", f"socket,id=vm-tpm,path={runtime}/tpm.sock", "-tpmdev", "emulator,id=vm-tpm-device,chardev=vm-tpm", "-device", "tpm-tis,tpmdev=vm-tpm-device"])
    if headless:
        args.extend(["-display", "none", "-serial", f"file:{runtime}/serial.log", "-nic", "none"])
    else:
        args.extend(["-display", "gtk,gl=off"])
        if p["network"]:
            args.extend(["-netdev", "user,id=vm-net", "-device", "e1000e,netdev=vm-net"])
        else:
            args.extend(["-nic", "none"])
        if p["audio"]:
            args.extend(["-audiodev", "pipewire,id=vm-audio", "-device", "ich9-intel-hda", "-device", "hda-duplex,audiodev=vm-audio"])
    return args
