"""GPT edge layouts, prepared installations and opt-in driver contracts."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("install_layout_regression",ROOT/"scripts/install_layout.py")
layout=importlib.util.module_from_spec(spec);spec.loader.exec_module(layout)
GIB=1024**3
ESP="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
LINUX="0fc63daf-8483-4772-8e79-3d69d8477de4"

class DriverSelection(unittest.TestCase):
    def setUp(self):
        self.catalog=json.loads((ROOT/"packages/driver-catalog.json").read_text())
        self.inventory={"graphics":[{"vendor":"0x8086"},{"vendor":"0x1002"}]}

    def test_only_selected_driver_packages_are_returned(self):
        self.assertEqual(layout.driver_packages([],self.inventory,self.catalog,True),[])
        self.assertEqual(layout.driver_packages(["intel-vulkan","intel-vulkan"],self.inventory,self.catalog),["vulkan-intel"])
        self.assertEqual(layout.driver_packages(["amd-vulkan"],self.inventory,self.catalog),["vulkan-radeon"])

    def test_wrong_vendor_offline_and_unsupported_drivers_are_rejected(self):
        for ids,info,offline in [(["amd-vulkan"],{"graphics":[{"vendor":"0x8086"}]},False),
            (["intel-vulkan"],self.inventory,True),(["nvidia"],self.inventory,False),
            (["intel-video"],self.inventory,False),(["--unsafe"],self.inventory,False),
            ("intel-vulkan",self.inventory,False)]:
            with self.subTest(ids=ids),self.assertRaises(ValueError):
                layout.driver_packages(ids,info,self.catalog,offline)

    def test_driver_catalog_cannot_inject_unapproved_packages(self):
        self.catalog["choices"][0]["packages"].append("git")
        with self.assertRaises(ValueError):layout.driver_packages(["intel-vulkan"],self.inventory,self.catalog)

@unittest.skipUnless(os.name=="posix" and shutil.which("jq"),"Requires Linux jq")
class GptInstallerRegression(unittest.TestCase):
    def raw(self,sector=512):
        size=64*GIB
        backup=(1+(16384+sector-1)//sector)*sector
        def part(number,start,end,fstype,kind):
            return dict(name="fixture"+str(number),path="/dev/fixture"+str(number),type="part",start=start//512,
                size=end-start,parttype=kind,partuuid="00000000-0000-0000-0000-"+str(number).zfill(12),
                fstype=fstype,mountpoints=[None],ro=False)
        return {"blockdevices":[dict(name="fixture",path="/dev/fixture",type="disk",size=size,
            model="GPT regression",serial="fixture",pttype="GPT",ro=False,**{"log-sec":sector},children=[
                part(1,1048576,257*1048576,"vfat",ESP),part(2,GIB,36*GIB,"ext4",LINUX),
                part(3,36*GIB,size-backup,"ntfs","de94bba4-06d1-4d40-a16a-bfd50179d6ac")]) ]}

    def inventory(self,raw):
        value=json.loads(subprocess.check_output(["jq","--argjson","live","true","--argjson","uefi","true",
            "-f",str(ROOT/"scripts/storage-inventory.jq")],input=json.dumps(raw).encode()))
        value.update(revision="fixture",executorAvailable=True,graphics=[],timezones=["UTC"],
            drivers=json.loads((ROOT/"packages/driver-catalog.json").read_text()))
        return value

    def review(self,inventory,**changes):
        disk=inventory["disks"][0]
        plan=dict(kind="install-alongside",revision="fixture",diskId=disk["id"],
            rootPartitionId=disk["partitions"][1]["id"],efiPartitionId=disk["partitions"][0]["id"],
            registerBootEntry=True,filesystem="ext4",selectedGroups=[],selectedDrivers=[],offline=True,
            locale="en_US.UTF-8",timezone="UTC",keyboard="us")
        plan.update(changes)
        with tempfile.TemporaryDirectory() as temporary:
            source=Path(temporary)/"inventory.json";source.write_text(json.dumps(inventory))
            storage=subprocess.check_output(["jq","-n","--slurpfile","inventory",str(source),"--slurpfile","catalog",
                str(ROOT/"packages/optional-catalog.yaml"),"--argjson","request",json.dumps(plan),"-f",str(ROOT/"scripts/storage-plan.jq")])
            checked=json.loads(subprocess.check_output(["jq","--argjson","request",json.dumps(plan),"--argjson","info",
                json.dumps(inventory),"-f",str(ROOT/"scripts/installer-review.jq")],input=storage))
        return layout.installation_review(plan,inventory,checked)

    def test_valid_partition_at_last_usable_sector_is_installable_512_and_4kn(self):
        for sector in (512,4096):
            with self.subTest(sector=sector):
                inventory=self.inventory(self.raw(sector));disk=inventory["disks"][0]
                self.assertEqual(disk["table"],"gpt")
                self.assertTrue(disk["geometryKnown"])
                self.assertLess(disk["unallocatedEstimate"],GIB)
                review=self.review(inventory)
                self.assertTrue(review["canExecute"],review["blockers"])
                self.assertEqual(review["layout"]["efi"]["path"],"/dev/fixture1")

    def test_gpt_at_first_usable_sector_does_not_require_one_mib_padding(self):
        raw=self.raw();raw["blockdevices"][0]["children"][0].update(start=34,size=100*1048576)
        self.assertTrue(self.inventory(raw)["disks"][0]["geometryKnown"])

    def test_overlap_and_backup_metadata_overlap_are_distinct_from_wrong_table_type(self):
        raw=self.raw();raw["blockdevices"][0]["children"][1]["start"]=2048
        review=self.review(self.inventory(raw))
        self.assertFalse(review["canExecute"])
        self.assertTrue(any("boundaries" in blocker for blocker in review["blockers"]))
        raw=self.raw();raw["blockdevices"][0]["children"][-1]["size"]+=512
        self.assertFalse(self.inventory(raw)["disks"][0]["geometryKnown"])

    def test_gpt_and_uefi_boot_mode_errors_are_independent(self):
        inventory=self.inventory(self.raw());inventory["uefi"]=False
        self.assertTrue(any("UEFI" in b for b in self.review(inventory)["blockers"]))
        raw=self.raw();raw["blockdevices"][0]["pttype"]="dos"
        self.assertTrue(any("not detected as GPT" in b for b in self.review(self.inventory(raw))["blockers"]))

    def test_mounts_stale_inventory_and_missing_payload_still_block(self):
        inventory=self.inventory(self.raw())
        self.assertFalse(self.review(inventory,revision="stale")["canExecute"])
        inventory["executorAvailable"]=False
        self.assertFalse(self.review(inventory)["canExecute"])
        inventory=self.inventory(self.raw());inventory["disks"][0]["partitions"][1]["mounted"]=True
        self.assertFalse(self.review(inventory)["canExecute"])

    def test_secure_boot_is_reported_before_installation(self):
        inventory=self.inventory(self.raw());inventory["secureBootEnabled"]=True
        review=self.review(inventory)
        self.assertFalse(review["canExecute"])
        self.assertTrue(any("Secure Boot" in b for b in review["blockers"]))

    def test_vulkan_selection_reaches_the_executable_review(self):
        inventory=self.inventory(self.raw());inventory["graphics"]=[{"vendor":"0x8086"}]
        result=self.review(inventory,offline=False,selectedDrivers=["intel-vulkan"])
        self.assertTrue(result["canExecute"],result["blockers"])
        self.assertEqual(result["driverPackages"],["vulkan-intel"])

    @unittest.skipUnless(shutil.which("sfdisk"),"Requires util-linux sfdisk")
    def test_real_sparse_gpt_image_fills_last_usable_sector(self):
        with tempfile.TemporaryDirectory(prefix="forynarch-gpt-") as folder:
            image=Path(folder)/"disposable.img"
            with image.open("wb") as stream:stream.truncate(64*GIB)
            subprocess.run(["sfdisk","--quiet",str(image)],input="label: gpt\nsize=256MiB,type=U\ntype=L\n",
                text=True,capture_output=True,check=True)
            table=json.loads(subprocess.check_output(["sfdisk","--json",str(image)]))["partitiontable"]
            raw=self.raw(table["sectorsize"]);raw["blockdevices"][0]["children"]=[]
            for index,part in enumerate(table["partitions"],1):
                raw["blockdevices"][0]["children"].append(dict(name="fixture"+str(index),path="/dev/fixture"+str(index),
                    type="part",start=part["start"]*table["sectorsize"]//512,size=part["size"]*table["sectorsize"],
                    partuuid=part["uuid"],parttype=part["type"],fstype="vfat" if index==1 else "ext4",mountpoints=[None],ro=False))
            inventory=self.inventory(raw)
            self.assertTrue(inventory["disks"][0]["geometryKnown"])
            self.assertTrue(self.review(inventory)["canExecute"])

if __name__=="__main__":unittest.main()
