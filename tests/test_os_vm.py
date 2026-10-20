import copy
import json
from pathlib import Path
import struct
import sys
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import forynarch_vm as vm


def fixture(sector=512):
    p = {"id":"11111111-1111-4111-8111-111111111111", "name":"Windows, test", "osPartuuid":"22222222-2222-4222-8222-222222222222",
         "efiPartuuid":"33333333-3333-4333-8333-333333333333", "efiPath":"EFI/Microsoft/Boot/bootmgfw.efi", "family":"windows",
         "mode":"preview", "memoryMiB":4096, "cpus":2, "controller":"auto", "recoveryKeyReady":False}
    rows = [{"path":"/dev/nvme0n1", "size":32*1024**3, "type":"disk", "serial":"OS-VM-FIXTURE", "maj:min":"259:0"},
            {"path":"/dev/nvme0n1p3", "parent":"/dev/nvme0n1", "size":8*1024**3, "type":"part", "partuuid":p["osPartuuid"], "fstype":"ntfs", "maj:min":"259:3", "mountpoints":[], "holders":[], "ro":False},
            {"path":"/dev/nvme0n1p1", "parent":"/dev/nvme0n1", "size":128*vm.MIB, "type":"part", "partuuid":p["efiPartuuid"], "parttype":vm.ESP_TYPE, "fstype":"vfat", "maj:min":"259:1", "mountpoints":["/boot"]},
            {"path":"/dev/nvme0n1p4", "parent":"/dev/nvme0n1", "size":8*1024**3, "type":"part", "fstype":"ext4", "mountpoints":["/"], "maj:min":"259:4"}]
    table = {"label":"gpt", "unit":"sectors", "device":"/dev/nvme0n1", "sectorsize":sector, "id":"44444444-4444-4444-8444-444444444444", "partitions":[
        {"node":"/dev/nvme0n1p3", "start":vm.MIB//sector, "size":8*1024**3//sector, "uuid":p["osPartuuid"], "type":"ebd0a0a2-b9e5-4433-87c0-68b6b72699c7"}]}
    return p, rows, table


def plan(p, rows, table, **options):
    return vm.make_plan(p, rows, table, available_bytes=12*1024**3, total_bytes=16*1024**3, host_cpus=8, ntfs_probe=options.pop("ntfs_probe", 0), **options)


class ExistingOsVm(unittest.TestCase):
    def test_legacy_profiles_keep_network_and_audio_without_accepting_truthy_values(self):
        p, _, _ = fixture()
        self.assertIs(vm.profile(p)["network"], True)
        self.assertIs(vm.profile(p)["audio"], True)
        for key in ("network", "audio"):
            for invalid in (0, 1, "false", None):
                with self.subTest(key=key, value=invalid), self.assertRaises(vm.VmError):
                    vm.profile(dict(p, **{key: invalid}))

    def test_network_and_audio_are_independent_and_bound_to_launch_review(self):
        p, rows, table = fixture()
        original = plan(p, rows, table)["digest"]
        for network in (False, True):
            for audio in (False, True):
                selected = dict(p, network=network, audio=audio)
                reviewed = plan(selected, rows, table)
                args = vm.qemu_command(reviewed, "/fixed/firmware", "/fixed/runtime", overlay_fd=4)
                with self.subTest(network=network, audio=audio):
                    self.assertEqual("-netdev" in args, network)
                    self.assertEqual("-audiodev" in args, audio)
                    self.assertEqual("-nic" in args, not network)
                    if not (network and audio):
                        self.assertNotEqual(original, reviewed["digest"])
                    self.assertIn("tpm-tis,tpmdev=vm-tpm-device", args)

    def test_both_bitlocker_signatures_require_recovery_and_read_only_backing(self):
        for signature in ("BitLocker", "crypto_bitlk"):
            p, rows, table = fixture()
            rows[1]["fstype"] = signature
            with self.subTest(signature=signature):
                with self.assertRaises(vm.VmError):
                    plan(p, rows, table, ntfs_probe=None)
                p["recoveryKeyReady"] = True
                reviewed = plan(p, rows, table, ntfs_probe=None)
                args = vm.qemu_command(reviewed, "/fixed/firmware", "/fixed/runtime", overlay_fd=4)
                nodes = [json.loads(args[i+1]) for i, value in enumerate(args) if value == "-blockdev"]
                self.assertTrue(nodes[0]["read-only"])
                self.assertEqual(nodes[-1]["driver"], "qcow2")
                p["mode"] = "direct"
                with self.assertRaises(vm.VmError):
                    plan(p, rows, table, ntfs_probe=None)

    def test_virtualization_tools_are_an_unchecked_group_outside_core(self):
        root=Path(__file__).resolve().parents[1]
        catalog=json.loads((root/"packages/optional-catalog.yaml").read_text())
        selected=next(group for group in catalog["groups"] if group["id"]=="experimental-os-vm")
        self.assertIs(selected["default"],False)
        self.assertEqual(set(selected["packages"]),set(vm.SUPPORT_PACKAGES))
        core={line.strip() for line in (root/"packages/target-core.proposed.txt").read_text().splitlines() if line.strip() and not line.startswith("#")}
        self.assertFalse(core & {"qemu-desktop","qemu-system-x86","qemu-base","swtpm"})

    def test_same_disk_host_root_is_never_an_extent(self):
        result = plan(*fixture())
        mapping = vm.mapper_table(result, "7:0", "7:1", "259:3")
        self.assertIn("error", mapping)
        self.assertNotIn("259:4", mapping)
        self.assertNotIn("259:1", mapping)
        self.assertNotIn("/dev/", mapping)
        extents = [line.split() for line in mapping.splitlines()]
        self.assertEqual(sum(int(e[1]) for e in extents), result["virtualSectors"])

    def test_mounted_swapped_or_held_source_and_descendant_are_blocked(self):
        for mutation in ({"mountpoints":["/drives/C"]}, {"mountpoints":["[SWAP]"]}, {"holders":["dm-0"]}):
            p, rows, table = fixture(); rows[1].update(mutation)
            with self.subTest(mutation=mutation), self.assertRaises(vm.VmError): plan(p, rows, table)
        p, rows, table = fixture()
        rows.append({"path":"/dev/mapper/host-root", "parent":rows[1]["path"], "mountpoints":["/"]})
        with self.assertRaises(vm.VmError): plan(p, rows, table)

    def test_ambiguous_identity_changed_geometry_and_non_gpt_fail(self):
        p, rows, table = fixture(); other = dict(rows[1], path="/dev/sdb3"); rows.append(other)
        with self.assertRaises(vm.VmError): plan(p, rows, table)
        p, rows, table = fixture(); table["partitions"][0]["size"] -= 1
        with self.assertRaises(vm.VmError): plan(p, rows, table)
        p, rows, table = fixture(); table["label"] = "dos"
        with self.assertRaises(vm.VmError): plan(p, rows, table)

    def test_hibernation_dirty_and_unknown_ntfs_states_never_force_repair(self):
        for code in (12,13,14,15,16,17,18,19,20,21,None):
            with self.subTest(code=code), self.assertRaises(vm.VmError): plan(*fixture(), ntfs_probe=code)

    def test_bitlocker_is_acknowledged_preview_only(self):
        p, rows, table = fixture(); rows[1]["fstype"] = "BitLocker"
        with self.assertRaises(vm.VmError): plan(p, rows, table)
        p["recoveryKeyReady"] = True
        self.assertEqual(plan(p, rows, table)["profile"]["mode"], "preview")
        p["mode"] = "direct"
        with self.assertRaises(vm.VmError): plan(p, rows, table)

    def test_gpt_crcs_and_geometry_for_512_and_4096(self):
        for sector in (512,4096):
            with self.subTest(sector=sector):
                result = plan(*fixture(sector)); primary, backup = vm.private_gpt(result)
                for header in (primary[sector:sector+92], backup[-sector:-sector+92]):
                    stored = struct.unpack_from("<I", header, 16)[0]
                    modified = bytearray(header); modified[16:20] = bytes(4)
                    self.assertEqual(stored, zlib.crc32(modified))
                self.assertEqual(primary[510:512], b"\x55\xaa")
                entries = primary[2*sector:2*sector+16384]
                self.assertEqual(zlib.crc32(entries), struct.unpack_from("<I", primary, sector+88)[0])
                self.assertEqual(primary[2*sector:2*sector+16384], backup[:16384])
                mapping = vm.mapper_table(result,"7:0","7:1","259:3")
                self.assertEqual(sum(int(line.split()[1]) for line in mapping.splitlines()), result["virtualSectors"]*sector//512)

    def test_resources_and_arbitrary_profile_fields_fail(self):
        for key, value in (("cpus",8),("cpus",True),("memoryMiB",16384),("efiPath","EFI/../../etc/shadow.efi"),("extraArgs","-drive /dev/sda"),("id","../bad")):
            p, rows, table = fixture(); p[key] = value
            with self.subTest(key=key), self.assertRaises(vm.VmError): plan(p, rows, table)

    def test_review_digest_changes_with_selected_geometry_mode_or_device(self):
        p, rows, table = fixture(); original=plan(p, rows, table)["digest"]
        p["mode"]="direct"; self.assertNotEqual(original,plan(p, rows, table)["digest"])
        p["mode"]="preview"; rows[1]["maj:min"]="259:99"
        self.assertNotEqual(original,plan(p, rows, table)["digest"])
        p,rows,table=fixture();rows[0]["serial"]="A DIFFERENT DISK"
        self.assertNotEqual(original,plan(p,rows,table)["digest"])

    def test_qemu_uses_only_mapped_descriptors_and_explicit_overlay(self):
        p, rows, table = fixture(); result=plan(p, rows, table)
        args=vm.qemu_command(result,"/usr/share/edk2/x64/OVMF_CODE.4m.fd","/run/forynarch-vm/1000/test/guest",overlay_fd=4)
        self.assertNotIn("/dev/nvme", " ".join(args));self.assertNotIn("/dev/sd", " ".join(args))
        nodes=[json.loads(args[i+1]) for i,value in enumerate(args) if value=="-blockdev"]
        self.assertTrue(nodes[0]["read-only"])
        self.assertEqual(nodes[-1]["backing"],"source")
        self.assertIn("guest=Windows,, test",args)
        self.assertNotIn("-snapshot",args)
        self.assertIn("spawn=allow",args[args.index("-sandbox")+1])
        headless=vm.qemu_command(result,"/fixed/firmware","/fixed/runtime",overlay_fd=4,headless=True)
        self.assertIn("spawn=deny",headless[headless.index("-sandbox")+1])
        with self.assertRaises(vm.VmError): vm.qemu_command(result,"/fixed/firmware","/fixed/runtime")
        p["mode"]="direct";args=vm.qemu_command(plan(p,rows,table),"/fixed/firmware","/fixed/runtime")
        self.assertNotIn("qcow2"," ".join(args))
