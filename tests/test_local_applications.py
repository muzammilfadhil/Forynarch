import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("local_applications", Path(__file__).resolve().parents[1] / "scripts/local_applications.py")
apps = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(apps)


class LocalApplications(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.bundle = Path(self.temporary.name)
        (self.bundle / "optional").mkdir()
        self.filename = "mudilmusic-3.9.0-2-x86_64.pkg.tar.zst"
        self.package = self.bundle / "optional" / self.filename
        self.package.write_bytes(b"fixture")
        self.record = {"filename": self.filename, "version": "3.9.0-2", "sha256": hashlib.sha256(b"fixture").hexdigest()}
        self.plan = {"selected_group_ids": ["mudilmusic"], "explicit_optional_packages": ["mudilmusic", "mpv", "libsecret"]}
        self.manifest()

    def manifest(self):
        (self.bundle / "local-applications.json").write_text(json.dumps({"schema_version": 1, "kind": "bundled-optional-applications", "packages": {"mudilmusic": self.record}}))

    def test_unselected_app_requires_no_binary(self):
        self.package.unlink()
        self.assertEqual(apps.verified_packages(self.bundle, {"explicit_optional_packages": []}), [])

    def test_local_selection_must_be_explicit(self):
        with self.assertRaises(ValueError):
            apps.selections({"selected_group_ids": [], "explicit_optional_packages": ["mudilmusic"]})

    def test_repo_plan_excludes_local_package(self):
        self.assertEqual(apps.selections(self.plan), (["mudilmusic"], ["libsecret", "mpv"]))

    def test_reviewed_hash_and_archive_are_required(self):
        with patch.object(apps, "inspect_package") as inspect:
            result = apps.verified_packages(self.bundle, self.plan)
            self.assertEqual(result[0]["version"], "3.9.0-2")
            inspect.assert_called_once_with(self.package, "mudilmusic", "3.9.0-2")

    def test_tampered_package_fails_before_inspection(self):
        self.package.write_bytes(b"tampered")
        with patch.object(apps, "inspect_package") as inspect, self.assertRaises(ValueError):
            apps.verified_packages(self.bundle, self.plan)
        inspect.assert_not_called()

    def test_package_path_cannot_escape_bundle(self):
        self.record["filename"] = "../" + self.filename
        self.manifest()
        with self.assertRaises(ValueError):
            apps.verified_packages(self.bundle, self.plan)

    def test_install_scripts_and_escaped_paths_are_rejected(self):
        for member in (".INSTALL", "opt/mudilmusic/../../etc/shadow", "/etc/shadow", "usr/bin/other"):
            with self.subTest(member=member), patch.object(apps.subprocess, "check_output", return_value=member + "\n"), self.assertRaises(ValueError):
                apps.inspect_package(self.package, "mudilmusic", "3.9.0-2")

    def test_wrong_archive_identity_is_rejected(self):
        with patch.object(apps.subprocess, "check_output", side_effect=["opt/mudilmusic/app\n.PKGINFO\n", "pkgname = other\npkgver = 3.9.0-2\narch = x86_64\n"]), self.assertRaises(ValueError):
            apps.inspect_package(self.package, "mudilmusic", "3.9.0-2")


if __name__ == "__main__":
    unittest.main()
