import copy
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location("audio_hardware",Path(__file__).resolve().parents[1]/"scripts/forynarch-audio-hardware.py")
audio=importlib.util.module_from_spec(spec);spec.loader.exec_module(audio)

class AudioHardware(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.environment=patch.dict(os.environ,{"XDG_STATE_HOME":self.temp.name});self.environment.start();self.addCleanup(self.environment.stop)
        self.card={"name":"alsa_card.fixture","active":"analog","profiles":[{"name":"off","available":True,"priority":0},{"name":"analog","available":True,"priority":10},{"name":"hdmi","available":False,"priority":20}]}

    def test_off_and_enable_restore_previous_profile_without_elevation(self):
        with patch.object(audio,"command") as command:
            audio.set_profile({"card":self.card["name"],"profile":"off"},[self.card])
            command.assert_called_with(["pactl","set-card-profile","alsa_card.fixture","off"])
            off=copy.deepcopy(self.card);off["active"]="off"
            audio.set_profile({"card":off["name"],"profile":"restore"},[off])
            command.assert_called_with(["pactl","set-card-profile","alsa_card.fixture","analog"])

    def test_disconnected_and_unavailable_profiles_do_not_mutate_audio(self):
        with patch.object(audio,"command") as command:
            for payload in ({"card":"missing","profile":"off"},{"card":self.card["name"],"profile":"hdmi"},{"card":self.card["name"],"profile":"off","extra":True}):
                with self.assertRaises(ValueError):audio.set_profile(payload,[self.card])
            command.assert_not_called()

    def test_restore_without_history_selects_available_profile(self):
        self.card["active"]="off"
        with patch.object(audio,"command") as command:
            audio.set_profile({"card":self.card["name"],"profile":"restore"},[self.card])
            command.assert_called_once_with(["pactl","set-card-profile","alsa_card.fixture","analog"])
