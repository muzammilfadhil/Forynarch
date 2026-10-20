import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

@unittest.skipIf(os.name == "nt", "Requires native flock support")
class ShowDesktop(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(); self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        spec = importlib.util.spec_from_file_location("desktop_control", Path(__file__).resolve().parents[1] / "scripts/forynarch-window-control.py")
        self.api = importlib.util.module_from_spec(spec); spec.loader.exec_module(self.api)
        self.file = self.directory / "minimized.json"
        self.clients = {"0x1": self.client("0x1", 1), "0x2": self.client("0x2", 2),
                        "0x3": self.client("0x3", 3, workspace=2), "0x4": self.client("0x4", 4, pinned=True)}
        self.state = {}
        self.moves = []
        def dispatch(operation, address, **kwargs):
            self.moves.append((operation, address, kwargs))
            if operation == "move":
                target = kwargs["workspace"]
                self.clients[address]["workspace"] = {"id": -99 if isinstance(target, str) else target,
                    "name": target if isinstance(target, str) else str(target)}
        self.mock = patch.object(self.api, "dispatch", side_effect=dispatch); self.mock.start(); self.addCleanup(self.mock.stop)
        self.hypr = patch.object(self.api, "hypr", return_value="ok"); self.hypr.start(); self.addCleanup(self.hypr.stop)

    @staticmethod
    def client(address, pid, workspace=1, pinned=False):
        return {"address": address, "pid":pid, "workspace":{"id":workspace,"name":str(workspace)},
                "mapped":True,"hidden":False,"pinned":pinned,"floating":True}

    def toggle(self):
        return self.api.show_desktop(self.directory, self.file, self.state, self.clients, 1, "0x2")

    def test_maximize_uses_monitor_handler_and_fullscreen_keeps_its_own_mode(self):
        for action in ("maximize","fullscreen"):
            self.moves.clear()
            def query(name):
                return list(self.clients.values()) if name=="clients" else {"id":1} if name=="activeworkspace" else {"address":"0x2"}
            with patch.object(self.api,"query",side_effect=query),patch.dict(os.environ,{"XDG_RUNTIME_DIR":str(self.directory)}),patch.object(self.api.sys,"argv",["control",action,"0x2"]):
                self.api.main()
            options=self.moves[-1][2]
            self.assertEqual(options["mode"],"maximized" if action=="maximize" else "fullscreen")
            if action=="maximize":self.assertIs(options["layout_aware"],False)
            else:self.assertNotIn("layout_aware",options)

    def test_only_local_visible_unpinned_windows_are_hidden_and_restored(self):
        self.toggle()
        self.assertEqual(set(self.state), {"0x1", "0x2"})
        self.assertEqual(self.clients["0x3"]["workspace"]["id"], 2)
        self.assertEqual(self.clients["0x4"]["workspace"]["id"], 1)
        self.toggle()
        self.assertEqual(self.state, {})
        self.assertEqual(self.clients["0x1"]["workspace"]["id"], 1)
        self.assertEqual(self.clients["0x2"]["workspace"]["id"], 1)
        self.assertFalse((self.directory / "desktop-1.json").exists())

    def test_previously_minimized_window_is_not_restored_by_group(self):
        self.clients["0x5"] = self.client("0x5", 5, workspace=-99)
        self.clients["0x5"]["workspace"]["name"] = "special:forynarch-minimized"
        self.state["0x5"] = {"pid":5,"workspace":1}
        self.toggle(); self.toggle()
        self.assertEqual(self.state, {"0x5":{"pid":5,"workspace":1}})

    def test_manual_relocation_to_another_workspace_stays_independent(self):
        self.toggle()
        self.state["0x2"]["workspace"] = 2
        self.toggle()
        self.assertEqual(self.state["0x2"]["workspace"], 2)
        self.assertEqual(self.clients["0x2"]["workspace"]["name"], "special:forynarch-minimized")

    def test_reused_window_identity_cannot_restore_an_old_snapshot(self):
        self.toggle()
        self.state["0x2"]["pid"] = 99
        self.clients["0x2"]["pid"] = 99
        self.toggle()
        self.assertIn("0x2", self.state)
        self.assertEqual(self.clients["0x2"]["workspace"]["name"], "special:forynarch-minimized")
