"""Read-only disk-model and proposal safety tests; never use real block devices."""
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
GIB = 1073741824
ESP = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
RECOVERY = "de94bba4-06d1-4d40-a16a-bfd50179d6ac"


@unittest.skipUnless(os.name != "nt" and shutil.which("jq"), "Requires Linux jq")
class PartitionPreparation(unittest.TestCase):
    def setUp(self):
        self.raw = {"blockdevices":[dict(name="sda",path="/dev/sda",type="disk",size=100*GIB,
            model="Test disk",serial="fixture-only",pttype="gpt",ro=False,children=[
                self.part("1",2048,512*1048576,"vfat",ESP),
                self.part("2",GIB//512,40*GIB,"ntfs"),
                self.part("3",42*GIB//512,GIB,"ntfs",RECOVERY)])]}

    @staticmethod
    def part(number,start,size,filesystem,parttype=""):
        return dict(name="sda"+number,path="/dev/sda"+number,type="part",start=start,size=size,
                    fstype=filesystem,parttype=parttype,partuuid="fixture-"+number,mountpoints=[None],ro=False)

    def inventory(self, raw=None):
        result = subprocess.run(["jq","--argjson","live","true","--argjson","uefi","true",
            "-f",str(ROOT/"scripts/storage-inventory.jq")],input=json.dumps(raw or self.raw),capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        inventory=json.loads(result.stdout)
        inventory["revision"]="fixture-revision"
        return inventory

    def review(self, kind="install-alongside", inventory=None, **values):
        inventory=inventory or self.inventory()
        request=dict(kind=kind,revision=inventory["revision"],diskId=inventory["disks"][0]["id"],
                     partitionId=inventory["disks"][0]["partitions"][1]["id"],filesystem="ext4",sizeGiB=32,
                     selectedGroups=[],offline=True)
        request.update(values)
        with tempfile.TemporaryDirectory() as temporary:
            path=Path(temporary)/"inventory.json"
            path.write_text(json.dumps(inventory))
            result=subprocess.run(["jq","-n","--slurpfile","inventory",str(path),"--slurpfile","catalog",
                str(ROOT/"packages/optional-catalog.yaml"),"--argjson","request",json.dumps(request),
                "-f",str(ROOT/"scripts/storage-plan.jq")],capture_output=True,text=True)
        return result

    def plan(self, **values):
        result=self.review(**values)
        self.assertEqual(result.returncode,0,result.stderr)
        value=json.loads(result.stdout)
        self.assertFalse(value["canExecute"])
        self.assertTrue(value["reviewOnly"])
        return value

    def test_gpt_gaps_and_512_byte_start_units(self):
        self.raw["blockdevices"][0]["log-sec"]=4096
        disk=self.inventory()["disks"][0]
        self.assertEqual(disk["partitions"][0]["start"],1048576)
        self.assertTrue(disk["geometryKnown"])
        self.assertGreater(disk["unallocatedEstimate"],32*GIB)
        self.assertTrue(disk["partitions"][0]["protected"])
        self.assertTrue(disk["partitions"][2]["protected"])

    def test_overlap_or_whole_device_filesystem_has_no_allocatable_gaps(self):
        self.raw["blockdevices"][0]["children"][1]["start"]=2048
        disk=self.inventory()["disks"][0]
        self.assertFalse(disk["geometryKnown"])
        self.assertEqual(disk["gaps"],[])
        self.raw["blockdevices"][0]["children"]=[]
        self.raw["blockdevices"][0]["fstype"]="ntfs"
        self.assertEqual(self.inventory()["disks"][0]["gaps"],[])

    def test_duplicate_identity_is_not_stable(self):
        self.raw["blockdevices"].append(copy.deepcopy(self.raw["blockdevices"][0]))
        self.assertTrue(all(not disk["stableIdentity"] for disk in self.inventory()["disks"]))

    def test_cancel_has_no_backend_execution_verb(self):
        result=subprocess.run(["bash",str(ROOT/"scripts/forynarch-storage.sh"),"execute"],capture_output=True,text=True)
        self.assertEqual(result.returncode,2)

    def test_alongside_is_review_only_and_preserves_existing_layout(self):
        before=copy.deepcopy(self.raw)
        plan=self.plan()
        self.assertIn("preserve other operating systems",plan["summary"])
        self.assertEqual(plan["optionalPackages"],[])
        self.assertEqual(plan["blockers"],[])
        self.assertEqual(self.raw,before)

    def test_prepared_install_does_not_require_a_second_unallocated_region(self):
        self.raw["blockdevices"][0]["children"][2]["size"]=57*GIB
        messages=" ".join(self.plan()["blockers"])
        self.assertNotIn("unallocated space",messages)

    def test_stale_revision_and_unknown_disk_are_blocked(self):
        messages=" ".join(self.plan(revision="old",diskId="unknown")["blockers"])
        self.assertIn("information changed",messages)
        self.assertIn("Select one currently",messages)

    def test_format_protected_mounted_and_encrypted_partitions_is_blocked(self):
        for number in (0,2):
            with self.subTest(number=number):
                partition=self.inventory()["disks"][0]["partitions"][number]
                self.assertIn("protected"," ".join(self.plan(kind="format",partitionId=partition["id"])["blockers"]))
        self.raw["blockdevices"][0]["children"][1]["mountpoints"]=["/media/data"]
        self.assertIn("protected"," ".join(self.plan(kind="delete")["blockers"]))
        self.raw["blockdevices"][0]["children"][1]["mountpoints"]=[None]
        self.raw["blockdevices"][0]["children"][1]["fstype"]="BitLocker"
        self.assertIn("protected"," ".join(self.plan(kind="format")["blockers"]))

    def test_running_system_disk_cannot_be_an_install_target(self):
        self.raw["blockdevices"][0]["children"][1]["mountpoints"]=["/"]
        self.assertIn("running system"," ".join(self.plan(kind="install-erase")["blockers"]))

    def test_create_size_and_resize_checks_fail_closed(self):
        self.assertIn("estimated unallocated"," ".join(self.plan(kind="create",sizeGiB=200)["blockers"]))
        self.assertIn("Partition Manager"," ".join(self.plan(kind="resize")["blockers"]))

    def test_optional_tools_require_selection_and_offline_plan_rejects_downloads(self):
        plan=self.plan(offline=False,selectedGroups=["nodejs-npm"])
        self.assertEqual(plan["optionalPackages"],["nodejs","npm"])
        self.assertNotIn("git",plan["optionalPackages"])
        self.assertIn("offline bundle"," ".join(self.plan(selectedGroups=["git"])["blockers"]))

    def test_malformed_actions_and_selections_are_rejected(self):
        for values in (dict(kind="execute"),dict(selectedGroups=["unknown"]),dict(offline="false"),dict(sizeGiB="32")):
            with self.subTest(values=values):
                self.assertNotEqual(self.review(**values).returncode,0)


if __name__=="__main__":
    unittest.main()
