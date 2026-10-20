import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('bluetooth_health',Path(__file__).resolve().parents[1]/'scripts/forynarch-bluetooth.py')
health=importlib.util.module_from_spec(spec);spec.loader.exec_module(health)

class BluetoothHealth(unittest.TestCase):
    def test_radio_blocks_are_reported_without_claiming_software_can_clear_hardware(self):
        service=subprocess.CompletedProcess([],0,'','')
        radios=subprocess.CompletedProcess([],0,'{"rfkilldevices":[{"type":"bluetooth","soft":"blocked","hard":"blocked"},{"type":"wlan","soft":"blocked","hard":"blocked"}]}','')
        with patch.object(health.subprocess,'run',side_effect=[service,radios]) as run:
            state=health.status()
            self.assertTrue(state['serviceRunning']);self.assertTrue(state['softBlocked']);self.assertTrue(state['hardBlocked'])
            self.assertNotIn('unblock',str(run.call_args_list))

    def test_unavailable_service_or_status_does_not_look_like_an_enabled_radio(self):
        with patch.object(health.subprocess,'run',side_effect=[subprocess.CompletedProcess([],3),subprocess.CompletedProcess([],1,'','')]):
            state=health.status()
            self.assertFalse(state['serviceRunning']);self.assertFalse(state['radioStatusKnown'])
