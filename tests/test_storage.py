"""Synthetic discovery and fail-closed action tests; never use real partitions."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
JQ = shutil.which("jq")
BASH = shutil.which("bash")


@unittest.skipUnless(JQ and BASH and os.name != "nt", "Requires Arch/Linux jq and Bash; no packages auto-installed")
class StorageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.devices = {"blockdevices": []}
        self.mounts = {"filesystems": []}
        self.mapping = {"version": 1, "drives": []}

    def volume(self, **changes):
        value = dict(path="/dev/fake1", type="part", fstype="ntfs", label="Windows",
                     uuid="AABB1122", partuuid="ABCDEF00-1111-2222-3333-444455556666",
                     parttype="ebd0a0a2-b9e5-4433-87c0-68b6b72699c7", size=128000000000,
                     mountpoints=[None], ro=False)
        value.update(changes)
        return value

    def model(self):
        for name, data in (("devices", self.devices), ("mounts", self.mounts), ("mapping", self.mapping)):
            (self.folder / f"{name}.json").write_text(json.dumps(data), encoding="utf-8")
        result = subprocess.run([JQ, "-n", "--slurpfile", "devices", str(self.folder / "devices.json"),
                                 "--slurpfile", "mounts", str(self.folder / "mounts.json"),
                                 "--slurpfile", "mapping", str(self.folder / "mapping.json"),
                                 "-f", str(ROOT / "scripts/storage-model.jq")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def backend(self, *args):
        binaries = self.folder / "bin"
        binaries.mkdir(exist_ok=True)
        for name, data in (("lsblk", self.devices), ("findmnt", self.mounts)):
            fixture = self.folder / f"{name}.json"
            fixture.write_text(json.dumps(data), encoding="utf-8")
            executable = binaries / name
            executable.write_text(f'#!/bin/sh\ncat "{fixture}"\n', encoding="utf-8")
            executable.chmod(0o755)
        for name, content in (("id", "echo 1000"), ("udisksctl", "exit 99"), ("thunar", "exit 99")):
            executable = binaries / name
            executable.write_text(f"#!/bin/sh\n{content}\n", encoding="utf-8")
            executable.chmod(0o755)
        env = dict(os.environ, PATH=str(binaries) + os.pathsep + os.environ["PATH"], XDG_CONFIG_HOME=str(self.folder / "config"))
        return subprocess.run([BASH, str(ROOT / "scripts/forynarch-drives.sh"), *args], env=env,
                              capture_output=True, text=True)

    def test_letters_follow_partition_ids_after_reordering(self):
        self.devices["blockdevices"] = [self.volume(path="/dev/fake2", partuuid="2222", label="Data"), self.volume()]
        self.mapping["drives"] = [{"id": "partuuid:abcdef00-1111-2222-3333-444455556666", "letter": "C", "label": "Windows"},
                                  {"id": "partuuid:2222", "letter": "D", "label": "Data"}]
        self.assertEqual([d["name"] for d in self.model()], ["Data (D:)", "Windows (C:)"])

    def test_unmapped_ntfs_never_guesses_c(self):
        self.devices["blockdevices"] = [self.volume()]
        self.assertEqual(self.model()[0]["letter"], "")

    def test_system_recovery_and_root_are_protected(self):
        self.devices["blockdevices"] = [self.volume(parttype=t) for t in
            ("c12a7328-f81f-11d2-ba4b-00a0c93ec93b", "e3c9e316-0b5c-4db8-817d-f92df00215ae", "de94bba4-06d1-4d40-a16a-bfd50179d6ac")]
        self.devices["blockdevices"].append(self.volume(fstype="ext4", mountpoints=["/"]))
        self.assertTrue(all(d["protected"] and not d["canMount"] for d in self.model()))

    def test_bitlocker_and_luks_cannot_mount(self):
        self.devices["blockdevices"] = [self.volume(fstype="BitLocker"), self.volume(fstype="crypto_LUKS")]
        self.assertTrue(all(d["locked"] and not d["canMount"] for d in self.model()))

    def test_bitlocker_cleartext_retains_original_identity_and_windows_letter(self):
        child = self.volume(path="/dev/mapper/clear-windows", type="crypt", partuuid="", mountpoints=["/run/media/user/Windows"], ro=True)
        parent = self.volume(fstype="crypto_bitlk", children=[child])
        self.devices["blockdevices"] = [parent]
        self.mapping["drives"] = [{"id":"partuuid:"+parent["partuuid"].lower(),"letter":"C","label":"Windows"}]
        rows = self.model()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["device"], child["path"])
        self.assertEqual(rows[0]["blockDevice"], parent["path"])
        self.assertEqual(rows[0]["name"], "Windows (C:)")
        self.assertTrue(rows[0]["encrypted"] and rows[0]["canMount"] and rows[0]["readOnly"])
        self.assertFalse(rows[0]["locked"] or rows[0]["canUnlock"])

    def test_encrypted_running_root_stays_protected(self):
        self.devices["blockdevices"] = [self.volume(fstype="crypto_LUKS", children=[self.volume(path="/dev/mapper/root", type="crypt", fstype="ext4", mountpoints=["/"])])]
        row = self.model()[0]
        self.assertTrue(row["protected"])
        self.assertFalse(row["canMount"] or row["canUnlock"])

    def test_locked_bitlocker_can_unlock_without_becoming_mountable(self):
        self.devices["blockdevices"] = [self.volume(fstype="crypto_bitlk")]
        row = self.model()[0]
        self.assertTrue(row["canUnlock"] and row["locked"])
        self.assertFalse(row["canMount"])

    def test_mount_access_mode_comes_from_mount_options(self):
        self.devices["blockdevices"] = [self.volume(mountpoints=["/run/media/user/Windows"])]
        self.mounts["filesystems"] = [{"target": "/run/media/user/Windows", "options": "ro,nosuid,nodev"}]
        self.assertTrue(self.model()[0]["readOnly"])
        self.mounts["filesystems"][0]["options"] = "rw,nosuid,nodev"
        self.assertFalse(self.model()[0]["readOnly"])

    def test_live_loop_and_optical_media_are_excluded(self):
        self.devices["blockdevices"] = [self.volume(type="loop"), self.volume(type="rom")]
        self.assertEqual(self.model(), [])

    def test_filesystem_uuid_fallback_and_unsupported_volume(self):
        self.devices["blockdevices"] = [self.volume(partuuid=None, fstype="exfat"), self.volume(fstype="unknown")]
        first, second = self.model()
        self.assertEqual(first["id"], "uuid:aabb1122")
        self.assertTrue(first["canMount"])
        self.assertFalse(second["canMount"])

    def test_invalid_and_duplicate_alias_import_fails(self):
        bad = self.folder / "bad.json"
        for drives in ([{"id": "uuid:abc", "letter": "C", "label": "Windows\nInjected"}],
                       [{"id": "uuid:abc", "letter": "C", "label": "One"}, {"id": "uuid:def", "letter": "C", "label": "Two"}],
                       [{"id": "uuid:$(touch-harm)", "letter": "D", "label": "Bad"}]):
            bad.write_text(json.dumps({"version": 1, "drives": drives}), encoding="utf-8")
            result = self.backend("import", str(bad))
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((self.folder / "config/forynarch/windows-drives.json").exists())

    def test_import_preserves_existing_mapping(self):
        valid = self.folder / "valid.json"
        valid.write_text(json.dumps({"version": 1, "drives": [{"id": "uuid:abc", "letter": "C", "label": "Windows"}]}))
        result = self.backend("import", str(valid))
        self.assertEqual(result.returncode, 0, result.stderr)
        saved = (self.folder / "config/forynarch/windows-drives.json").read_text()
        self.assertNotEqual(self.backend("import", str(valid)).returncode, 0)
        self.assertEqual((self.folder / "config/forynarch/windows-drives.json").read_text(), saved)

    def test_windows_merge_updates_letters_and_preserves_unrelated_aliases(self):
        initial = self.folder / "initial.json"
        incoming = self.folder / "incoming.json"
        initial.write_text(json.dumps({"version":1,"drives":[{"id":"uuid:abc","letter":"D","label":"Old"},{"id":"uuid:xyz","letter":"G","label":"Archive"}]}))
        incoming.write_text(json.dumps({"version":1,"drives":[{"id":"uuid:abc","letter":"C","label":"Windows"}]}))
        self.assertEqual(self.backend("import",str(initial)).returncode, 0)
        result = self.backend("merge",str(incoming))
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = json.loads((self.folder/"config/forynarch/windows-drives.json").read_text())["drives"]
        self.assertEqual({r["id"]:r["letter"] for r in rows}, {"uuid:abc":"C","uuid:xyz":"G"})

    def test_duplicate_device_identifier_prevents_action(self):
        self.devices["blockdevices"] = [self.volume(partuuid="abc"), self.volume(partuuid="abc", path="/dev/fake2")]
        result = self.backend("mount-ro", "partuuid:abc")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ambiguous", result.stderr)

    def test_locked_volume_prevents_action(self):
        self.devices["blockdevices"] = [self.volume(partuuid="abc", fstype="BitLocker")]
        result = self.backend("mount-ro", "partuuid:abc")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Locked", result.stderr)

    def test_alias_letter_collision_is_rejected(self):
        self.devices["blockdevices"] = [self.volume(partuuid="abc"), self.volume(partuuid="def", label="Data")]
        self.assertEqual(self.backend("alias", "partuuid:abc", "D").returncode, 0)
        result = self.backend("alias", "partuuid:def", "D")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("another drive", result.stderr)

    def test_mounted_alias_adds_uri_encoded_bookmark(self):
        self.devices["blockdevices"] = [self.volume(partuuid="abc", mountpoints=["/run/media/user/My Data"])]
        result = self.backend("alias", "partuuid:abc", "D")
        self.assertEqual(result.returncode, 0, result.stderr)
        bookmark = self.folder / "config/gtk-3.0/bookmarks"
        self.assertEqual(bookmark.read_text(), "file:///run/media/user/My%20Data Windows (D:)\n")
        self.assertEqual(self.backend("alias", "partuuid:abc", "D").returncode, 0)
        self.assertEqual(len(bookmark.read_text().splitlines()), 1)

    def test_existing_user_bookmark_label_is_preserved(self):
        self.devices["blockdevices"] = [self.volume(partuuid="abc", mountpoints=["/run/media/user/Windows"])]
        bookmark = self.folder / "config/gtk-3.0/bookmarks"
        bookmark.parent.mkdir(parents=True)
        bookmark.write_text("file:///run/media/user/Windows My existing label\n")
        self.assertEqual(self.backend("alias", "partuuid:abc", "C").returncode, 0)
        self.assertEqual(bookmark.read_text(), "file:///run/media/user/Windows My existing label\n")
