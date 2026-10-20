import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("date_time", ROOT / "scripts/forynarch-date-time.py")
clock = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(clock)

class DateTimeSettings(unittest.TestCase):
    def test_status_distinguishes_enabled_from_synchronized(self):
        with patch.object(clock, "invoke", return_value="Timezone=Asia/Jakarta\nNTP=yes\nNTPSynchronized=no\nCanNTP=yes\nLocalRTC=no\n"):
            state = clock.status()
        self.assertTrue(state["ntp"])
        self.assertFalse(state["synced"])
        self.assertEqual(state["timezone"], "Asia/Jakarta")

    def test_timezone_must_be_in_system_database(self):
        with patch.object(clock, "invoke", return_value="UTC\nAsia/Jakarta\n") as service:
            clock.change("timezone", "Asia/Jakarta")
            self.assertEqual(service.call_args.args, ("set-timezone", "Asia/Jakarta"))
            with self.assertRaises(ValueError): clock.change("timezone", "../etc/passwd")
            with self.assertRaises(ValueError): clock.change("timezone", "UTC; touch bad")

    def test_clock_change_never_disables_network_time_implicitly(self):
        with patch.object(clock, "status", return_value={"ntp": True}), patch.object(clock, "invoke") as service:
            with self.assertRaises(ValueError): clock.change("time", "2026-10-16 14:30:00")
            service.assert_not_called()

    def test_manual_time_is_validated_and_passed_as_one_argument(self):
        with patch.object(clock, "status", return_value={"ntp": False}), patch.object(clock, "invoke") as service:
            clock.change("time", "2026-10-16 14:30")
            service.assert_called_once_with("set-time", "2026-10-16 14:30:00")
            for value in ["2026-02-30 14:30:00", "2026-10-16 14:30;reboot", "now", "-1"]:
                with self.assertRaises(ValueError): clock.change("time", value)

    def test_ntp_accepts_only_explicit_boolean_choices(self):
        with patch.object(clock, "invoke") as service:
            clock.change("ntp", "on")
            service.assert_called_once_with("set-ntp", "true")
            with self.assertRaises(ValueError): clock.change("ntp", "true; reboot")
