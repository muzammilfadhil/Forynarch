"""Separate browser profiles and untrusted desktop entry fields."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == "posix" and shutil.which("jq"), "Arch shell tools required")
class WebApps(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        binary = self.home / "bin"
        binary.mkdir()
        for command, body in {"chromium":'printf "%s\\n" "$@" > "$HOME/arguments"', "curl":"exit 22"}.items():
            path = binary / command
            path.write_text("#!/bin/sh\n" + body + "\n")
            path.chmod(0o755)
        self.env = {**os.environ, "HOME":str(self.home), "XDG_DATA_HOME":str(self.home / "data"), "PATH":str(binary) + ":" + os.environ["PATH"]}

    def call(self, *args, request=None):
        return subprocess.run(["bash", str(ROOT / "scripts/forynarch-webapps.sh"), *args], input=json.dumps(request) if request else None, text=True, capture_output=True, env=self.env)

    def create(self, **changes):
        return self.call("create", request={"name":"Work mail", "url":"https://example.com/mail", "browser":"chromium", "icon":"", **changes})

    def test_two_accounts_never_share_cookie_profiles(self):
        for _ in range(2):
            result = self.create()
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        rows=json.loads(self.call("list").stdout)["apps"]
        self.assertEqual(len(rows),2)
        self.assertNotEqual(rows[0]["id"],rows[1]["id"])
        for row in rows:
            result=self.call("launch",row["id"])
            self.assertEqual(result.returncode,0,result.stderr)
            args=(self.home/"arguments").read_text().splitlines()
            profile=self.home/"data/forynarch/webapps"/row["id"]
            self.assertIn("--user-data-dir="+str(profile),args)
            self.assertEqual(profile.stat().st_mode & 0o777,0o700)
            self.assertIn("--app=https://example.com/mail",args)

    def test_removing_shortcut_retains_account_data(self):
        self.assertEqual(self.create().returncode,0)
        row=json.loads(self.call("list").stdout)["apps"][0]
        profile=self.home/"data/forynarch/webapps"/row["id"]
        (profile/"cookies").write_text("synthetic cookie")
        self.assertEqual(self.call("remove",row["id"]).returncode,0)
        self.assertEqual(json.loads(self.call("list").stdout)["apps"],[])
        self.assertEqual((profile/"cookies").read_text(),"synthetic cookie")
        self.assertNotEqual(self.call("launch",row["id"]).returncode,0)

    def test_desktop_injection_and_non_web_urls_are_rejected(self):
        for request in [{"name":"Mail\nExec=touch /tmp/unwanted"},{"url":"file:///etc/passwd"},{"url":"https://user:password@example.com"},{"url":"javascript:alert(1)"},{"url":"https://example.com/ --disable-web-security"},{"browser":"bash"},{"icon":"file:///etc/passwd"}]:
            with self.subTest(request=request):
                self.assertNotEqual(self.create(**request).returncode,0)
        self.assertNotEqual(self.call("remove","../../unrelated").returncode,0)
