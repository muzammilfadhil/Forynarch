import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec=importlib.util.spec_from_file_location("install_layout",Path(__file__).resolve().parents[1]/"scripts/install_layout.py")
layout=importlib.util.module_from_spec(spec);spec.loader.exec_module(layout)

class PreparedInstall(unittest.TestCase):
    def setUp(self):
        self.root=dict(id="partuuid:00000000-0000-0000-0000-000000000003",partitionUuid="00000000-0000-0000-0000-000000000003",path="/dev/fixture3",filesystem="ext4",size=40*1024**3,partitionType="0fc63daf-8483-4772-8e79-3d69d8477de4",mounted=False,readOnly=False,encrypted=False,protected=False)
        self.efi=dict(self.root,id="partuuid:00000000-0000-0000-0000-000000000001",partitionUuid="00000000-0000-0000-0000-000000000001",path="/dev/fixture1",filesystem="vfat",partitionType=layout.ESP,size=256*1024**2,protected=True)
        disk=dict(id="serial:fixture",path="/dev/fixture",stableIdentity=True,readOnly=False,containsSystem=False,table="gpt",geometryKnown=True,partitions=[self.efi,self.root])
        self.inventory=dict(live=True,uefi=True,revision="current",executorAvailable=True,disks=[disk])
        self.plan=dict(kind="install-alongside",revision="current",diskId=disk["id"],filesystem="ext4",rootPartitionId=self.root["id"],efiPartitionId=self.efi["id"],registerBootEntry=True)

    def test_existing_efi_is_not_treated_as_a_root_format_target(self):
        result=layout.prepared_layout(self.plan,self.inventory)
        self.assertEqual(result["root"]["path"],"/dev/fixture3")
        self.assertEqual(result["efi"]["path"],"/dev/fixture1")
        self.assertIn("preserve",result["summary"])

    def test_windows_encryption_recovery_mount_and_stale_geometry_are_rejected(self):
        for change in ({"filesystem":"ntfs"},{"filesystem":"exfat"},{"filesystem":"Unknown","partitionType":"ebd0a0a2-b9e5-4433-87c0-68b6b72699c7"},{"encrypted":True},{"protected":True},{"mounted":True},{"readOnly":True},{"size":1024}):
            with self.subTest(change=change):
                info=copy.deepcopy(self.inventory);info["disks"][0]["partitions"][1].update(change)
                with self.assertRaises(ValueError):layout.prepared_layout(self.plan,info)
        for change in ({"revision":"changed"},{"live":False},{"uefi":False}):
            with self.assertRaises(ValueError):layout.prepared_layout(self.plan,dict(self.inventory,**change))

    def test_another_disk_duplicate_partition_and_nonfat_esp_are_rejected(self):
        for field,value in (("efiPartitionId",self.root["id"]),("rootPartitionId","partuuid:missing"),("registerBootEntry","true")):
            with self.assertRaises(ValueError):layout.prepared_layout(dict(self.plan,**{field:value}),self.inventory)
        info=copy.deepcopy(self.inventory);info["disks"][0]["partitions"][0]["filesystem"]="ext4"
        with self.assertRaises(ValueError):layout.prepared_layout(self.plan,info)

    def test_valid_assignments_do_not_clear_unrelated_review_blockers(self):
        result=layout.installation_review(self.plan,self.inventory,{"blockers":["Unsupported driver selection"]})
        self.assertFalse(result["canExecute"])
        self.assertIn("Unsupported driver selection",result["blockers"])
        self.assertTrue(layout.installation_review(self.plan,self.inventory,{"blockers":[]})["canExecute"])

    def test_boot_menu_includes_windows_and_other_efi_systems_without_injection(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)/"EFI"
            for name,path in (("Microsoft","Boot/bootmgfw.efi"),("ubuntu","grubx64.efi"),("Forynarch","grubx64.efi"),("Forynarch-backup-fixture","grubx64.efi"),("bad'name","grubx64.efi")):
                target=root/name/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(b"fixture")
            result=layout.boot_entries(folder,"ABCD-1234")
            self.assertIn("Windows Boot Manager",result);self.assertIn("Existing EFI system: ubuntu",result)
            self.assertNotIn("bad'name",result);self.assertNotIn("/EFI/Forynarch",result)
            with self.assertRaises(ValueError):layout.boot_entries(folder,"UUID'; reboot")
