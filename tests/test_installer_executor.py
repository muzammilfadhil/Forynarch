import copy
import importlib.util
import os
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
executor = None
if os.name == "posix":
    spec = importlib.util.spec_from_file_location("system_executor", ROOT / "scripts/forynarch-install-system.py")
    executor = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(executor)


@unittest.skipUnless(executor is not None, "requires Linux fcntl and subprocess runtime")
class InstallerTransport(unittest.TestCase):
    def setUp(self):
        self.plan = dict(kind="install-erase", revision="snapshot", diskId="serial:test", offline=True,
                         selectedGroups=[], filesystem="ext4", sizeGiB=32, locale="en_US.UTF-8", timezone="UTC",
                         keyboard="us", fullName="QA Account", username="qatest", hostname="qa-host",
                         selectedDrivers=[], passwordless=False, reviewOnly=True)
        self.request = dict(plan=self.plan, password="Fixture password 123!", confirmation="Fixture password 123!", consent="ERASE /dev/test-disk")
        self.inventory = dict(revision="snapshot", disks=[dict(id="serial:test", path="/dev/test-disk", stableIdentity=True, containsSystem=False, readOnly=False)])
        self.review = {"canExecute": True}

    def test_confirmed_plan_keeps_secrets_out_of_arguments(self):
        plan, disk = executor.validate_request(self.request, self.inventory, self.review)
        arguments = executor.installer_arguments(plan, "/dev/disk/by-id/test-disk")
        self.assertNotIn(self.request["password"], " ".join(arguments))
        self.assertIn("--gui", arguments)
        self.assertNotIn("--select", arguments)
        self.assertEqual(disk["path"], "/dev/test-disk")

    def test_supported_driver_selection_is_passed_without_enabling_software_groups(self):
        self.plan.update(offline=False,selectedDrivers=["intel-vulkan"])
        plan,_=executor.validate_request(self.request,self.inventory,self.review)
        arguments=executor.installer_arguments(plan,"/dev/disk/by-id/test-disk")
        self.assertEqual(arguments[arguments.index("--driver")+1],"intel-vulkan")
        self.assertNotIn("--select",arguments)
        self.plan["offline"]=True
        with self.assertRaises(ValueError):executor.validate_request(self.request,self.inventory,self.review)

    def test_every_offered_software_group_is_accepted(self):
        import json
        catalogue=json.loads((ROOT / "packages/optional-catalog.yaml").read_text())
        for group in catalogue["groups"]:
            with self.subTest(group=group["id"]):
                self.plan["selectedGroups"]=[group["id"]]
                executor.validate_request(self.request,self.inventory,self.review)

    def test_preflight_survives_pkexec_sanitized_path(self):
        import json
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as temporary:
            child=Path(temporary)/"preflight.py"
            child.write_text('import json,os; print(json.dumps({"path":os.environ["PATH"],"caller":os.environ.get("FORYNARCH_TEST_CALLER_SECRET")}))')
            with patch.dict(os.environ,{"PATH":"/usr/bin","FORYNARCH_TEST_CALLER_SECRET":"fixture-secret"}):
                result=executor.checked_json([sys.executable,str(child)])
            self.assertEqual(result["path"],"/usr/local/sbin:/usr/local/bin:/usr/bin")
            self.assertIsNone(result["caller"])

    def test_passwordless_is_explicit_and_does_not_select_software(self):
        self.plan["passwordless"] = True
        self.request["password"] = self.request["confirmation"] = ""
        plan, _ = executor.validate_request(self.request, self.inventory, self.review)
        arguments = executor.installer_arguments(plan, "/dev/disk/by-id/test-disk")
        self.assertIn("--no-password", arguments)
        self.assertNotIn("--select", arguments)

    def test_stale_disk_wrong_confirmation_and_protected_targets_are_rejected(self):
        for case in ("revision", "confirmation", "protected", "read-only", "ambiguous", "unavailable"):
            request, inventory, review = copy.deepcopy((self.request, self.inventory, self.review))
            if case == "revision": inventory["revision"] = "changed"
            if case == "confirmation": request["consent"] = "ERASE /dev/another-disk"
            if case == "protected": inventory["disks"][0]["containsSystem"] = True
            if case == "read-only": inventory["disks"][0]["readOnly"] = True
            if case == "ambiguous": inventory["disks"].append(inventory["disks"][0])
            if case == "unavailable": review["canExecute"] = False
            with self.subTest(case=case), self.assertRaises(ValueError):
                executor.validate_request(request, inventory, review)

    def test_private_fields_cannot_enter_the_public_review(self):
        self.plan["password"] = self.request["password"]
        with self.assertRaises(ValueError):
            executor.public_fields(self.request)

    def test_invalid_account_password_and_method_are_rejected(self):
        for field, value in (("username", "root"), ("username", "name;command"), ("hostname", "bad/host"), ("filesystem", "btrfs"), ("kind", "install-alongside"), ("offline", 1), ("selectedDrivers", ["unreviewed"]), ("selectedGroups", ["--unsafe"])):
            request = copy.deepcopy(self.request)
            request["plan"][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                executor.validate_request(request, self.inventory, self.review)
        self.request["password"] = "bad\npassword"
        with self.assertRaises(ValueError):
            executor.validate_request(self.request, self.inventory, self.review)

    def test_actual_child_protocol_reports_completion_without_logging_password(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            child = root / "fixture.py"
            child.write_text("import sys\nassert sys.stdin.readline().startswith('ERASE ALL DATA ON ')\nassert len(sys.stdin.readline().strip()) >= 8\nprint('FORYNARCH_STAGE extract', flush=True)\nprint('FORYNARCH_STAGE complete', flush=True)\n")
            events = []
            private_input = "ERASE ALL DATA ON /dev/disk/by-id/test-disk\n" + self.request["password"] + "\n"
            result = executor.run_installation([sys.executable, str(child)], private_input, root / "logs", events.append)
            self.assertEqual(result, 0)
            self.assertEqual([event["stage"] for event in events if event.get("kind") != "log"], ["prepare", "extract", "complete"])
            self.assertNotIn(self.request["password"], (root / "logs/installation.log").read_text())
            self.assertEqual((root / "logs/installation.log").stat().st_mode & 0o777, 0o600)

    def test_failure_reports_stage_output_exit_code_and_disk_state(self):
        import json
        for phase, marker, changed in (("download", "", False), ("partition", "FORYNARCH_DISK_WRITE", True), ("flatpak", "", True)):
            with self.subTest(phase=phase), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                child = root / "failure.py"
                child.write_text("import sys\nsys.stdin.read()\nprint('FORYNARCH_STAGE " + phase + "')\nprint('" + marker + "')\nprint('error: fixture dependency unavailable',file=sys.stderr)\nsys.exit(17)\n")
                events = []
                result = executor.run_installation([sys.executable, str(child)], "fixture consent\n", root / "logs", events.append)
                status = events[-1]
                self.assertEqual(result, 17)
                self.assertEqual(status["stage"], "failed")
                self.assertEqual(status["failedStage"], phase)
                self.assertEqual(status["exitCode"], 17)
                self.assertEqual(status["diskMayHaveChanged"], changed)
                self.assertIn("fixture dependency unavailable", status["details"])
                self.assertEqual(json.loads((root / "logs/status.json").read_text()), status)
                self.assertEqual((root / "logs/status.json").stat().st_mode & 0o777, 0o600)

    def test_diagnostics_redact_accidentally_echoed_secrets_and_bound_output(self):
        import json
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            child = root / "failure.py"
            child.write_text("import sys\nsecret=sys.stdin.read().splitlines()[1]\nprint('FORYNARCH_STAGE download')\nprint('\\x1b[31m'+secret+'\\x1b[0m',flush=True)\n" +
                             "\nfor i in range(100):print('x'*3000)\nprint(secret)\nsys.exit(1)\n")
            events = []
            secret = "Fixture-\x1b[32mpassword-123!"
            executor.run_installation([sys.executable, str(child)], "consent\n" + secret + "\n", root / "logs", events.append)
            self.assertNotIn(secret, (root / "logs/installation.log").read_text())
            self.assertNotIn("Fixture-password-123!", (root / "logs/installation.log").read_text())
            self.assertNotIn(secret, json.dumps(events))
            self.assertNotIn("\x1b", (root / "logs/installation.log").read_text())
            self.assertLessEqual(len(events[-1]["details"]), 16000)
            self.assertIn("[redacted]", events[-1]["details"])

    def test_non_utf8_output_keeps_real_exit_code_and_failure_details(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            child = root / "bytes.py"
            private_input = "consent\nF\u00f8rynarch-\u79d8\u5bc6123\n"
            child.write_text("import os,time,sys\nassert sys.stdin.buffer.read() == " + repr(private_input.encode("utf-8")) + "\nos.write(1,b'FORYNARCH_STAGE download\\n')\ntime.sleep(.1)\nos.write(1,b'packager: Ren\\xc3\\xa9\\n')\nos.write(1,b'error: fixture bytes \\xff\\xfe\\n')\nraise SystemExit(17)\n", encoding="utf-8")
            events = []
            result = executor.run_installation([sys.executable, str(child)], private_input, root / "logs", events.append)
            self.assertEqual(result, 17)
            self.assertEqual(events[-1]["stage"], "failed")
            self.assertEqual(events[-1]["failedStage"], "download")
            self.assertEqual(events[-1]["exitCode"], 17)
            self.assertIs(events[-1]["diskMayHaveChanged"], False)
            self.assertIn("fixture bytes", events[-1]["details"])
            self.assertIn("Ren\u00e9", events[-1]["details"])
            self.assertIn("\ufffd", (root / "logs/installation.log").read_text(encoding="utf-8"))

    def test_full_log_filesystem_does_not_interrupt_the_child_or_lose_its_result(self):
        from unittest.mock import patch
        original_fdopen = os.fdopen
        class FullLog:
            def __init__(self, stream): self.stream = stream
            def __enter__(self): return self
            def __exit__(self, *args): self.stream.close()
            def write(self, data): raise OSError(28, "fixture filesystem full")
        def fdopen(descriptor, mode, **kwargs):
            stream = original_fdopen(descriptor, mode, **kwargs)
            return FullLog(stream) if mode == "wb" else stream
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            child = root / "failure.py"
            child.write_text("import sys\nsys.stdin.read()\nprint('FORYNARCH_STAGE extract')\nprint('error: fixture root extraction failed')\nraise SystemExit(19)\n")
            events = []
            with patch.object(executor.os, "fdopen", side_effect=fdopen):
                result = executor.run_installation([sys.executable, str(child)], "consent\n", root / "logs", events.append)
            self.assertEqual(result, 19)
            self.assertTrue(events[-1]["diskMayHaveChanged"])
            self.assertIn("fixture root extraction failed", events[-1]["details"])
            self.assertIn("errno 28", events[-1]["loggingWarning"])

    def test_status_file_write_failure_does_not_abort_execution(self):
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            child = root / "success.py"
            child.write_text("import sys\nsys.stdin.read()\nprint('FORYNARCH_STAGE verify')\nprint('FORYNARCH_STAGE complete')\n")
            events = []
            with patch.object(Path, "replace", side_effect=OSError(28, "fixture status filesystem full")):
                result = executor.run_installation([sys.executable, str(child)], "consent\n", root / "logs", events.append)
            self.assertEqual(result, 0)
            self.assertEqual(events[-1]["stage"], "complete")
            self.assertIn("errno 28", events[-1]["loggingWarning"])

    def test_zero_exit_without_completion_marker_has_unknown_disk_state(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            child = root / "incomplete.py"
            child.write_text("import sys\nsys.stdin.read()\nprint('FORYNARCH_STAGE download')\n")
            events = []
            result = executor.run_installation([sys.executable, str(child)], "consent\n", root / "logs", events.append)
            self.assertEqual(result, 1)
            self.assertEqual(events[-1]["stage"], "failed")
            self.assertIsNone(events[-1]["diskMayHaveChanged"])
            self.assertIn("without its completion marker", events[-1]["details"])

    def test_live_log_is_redacted_bounded_and_throttled_without_overwriting_status(self):
        import json
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            child = root / "logs.py"
            child.write_text("import sys\nsecret=sys.stdin.read().splitlines()[1]\nprint('FORYNARCH_STAGE download')\nfor i in range(1000):print(secret+' '+str(i)+' '+'x'*300)\nraise SystemExit(17)\n")
            events = []
            with patch.object(executor.time, "monotonic", return_value=100.0):
                result = executor.run_installation([sys.executable, str(child)], "consent\nFixture-secret-123!\n", root / "logs", events.append)
            logs = [event for event in events if event.get("kind") == "log"]
            self.assertEqual(result, 17)
            self.assertEqual(len(logs), 2)
            self.assertLessEqual(len(logs[-1]["text"]), 49152)
            self.assertIn("[redacted]", logs[-1]["text"])
            self.assertNotIn("Fixture-secret-123!", json.dumps(events))
            self.assertEqual(json.loads((root / "logs/status.json").read_text()), events[-1])

    def test_password_redaction_cannot_hide_protocol_completion(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            child = root / "protocol.py"
            child.write_text("import sys\nsys.stdin.read()\nprint('FORYNARCH_STAGE verify')\nprint('FORYNARCH_STAGE complete')\n")
            events = []
            result = executor.run_installation([sys.executable, str(child)], "consent\nFORYNARCH\n", root / "logs", events.append)
            self.assertEqual(result, 0)
            self.assertEqual(events[-1]["stage"], "complete")
            self.assertNotIn("FORYNARCH", (root / "logs/installation.log").read_text())


if __name__ == "__main__":
    unittest.main()
