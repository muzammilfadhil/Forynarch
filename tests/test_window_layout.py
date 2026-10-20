import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipIf(os.name == "nt", "Requires Linux runtime helpers")
class WindowLayouts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("window_layout", ROOT / "scripts/forynarch-window-layout.py")
        cls.helper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.helper)

    def test_halves_leave_panel_and_shared_border_space(self):
        monitor = dict(width=1920, height=1080, scale=1, x=0, y=0, reserved=[0, 56, 0, 0])
        self.assertEqual(self.helper.region_box(monitor, "left"), (4, 60, 952, 1016))
        self.assertEqual(self.helper.region_box(monitor, "right"), (964, 60, 952, 1016))

    def test_thirds_fit_work_area_without_overlap(self):
        monitor = dict(width=1920, height=1080, scale=1, x=0, y=0, reserved=[0, 56, 0, 0])
        boxes = [self.helper.region_box(monitor, name) for name in ("third-left", "third-middle", "third-right")]
        self.assertEqual(boxes, [(4, 60, 632, 1016), (644, 60, 632, 1016), (1284, 60, 632, 1016)])

    def test_rotated_scaled_display_with_negative_origin(self):
        monitor = dict(width=1920, height=1080, scale=1.5, transform=1, x=-720, y=0, reserved=[0, 56, 0, 0])
        self.assertEqual(self.helper.region_box(monitor, "bottom-right"), (-356, 672, 352, 604))

    def test_small_work_area_is_rejected(self):
        with self.assertRaises(ValueError):
            self.helper.region_box(dict(width=100, height=100, scale=1, x=0, y=0), "left")

    def test_duplicate_pair_and_foreign_address_do_not_mutate_windows(self):
        client = dict(address="0x1", pid=8, workspace={"id":1}, monitor=0, mapped=True, hidden=False, grouped=[])
        for addresses in (["0x1", "0x1"], ["0x1", "0x2"], ["0x1", '0x1);bad()']):
            with self.subTest(addresses=addresses), tempfile.TemporaryDirectory() as directory:
                with patch.dict(os.environ, {"XDG_RUNTIME_DIR":directory}), patch.object(self.helper, "query", side_effect=[{"id":1}, [client]]):
                    with patch.object(self.helper, "dispatch") as dispatch, patch.object(self.helper, "hypr") as hypr:
                        with self.assertRaises(ValueError):
                            self.helper.apply("pair-horizontal", addresses)
                        dispatch.assert_not_called()
                        hypr.assert_not_called()

    def test_restore_does_not_touch_reused_or_moved_window(self):
        snapshot = dict(workspace=1, layout="dwindle", windows=[
            dict(address="0x1", pid=4), dict(address="0x2", pid=6)])
        current = [dict(address="0x1", pid=5, workspace={"id":1}), dict(address="0x2", pid=6, workspace={"id":2})]
        with patch.object(self.helper, "dispatch") as dispatch, patch.object(self.helper, "hypr"):
            self.helper.restore(snapshot, current)
            dispatch.assert_not_called()

    def test_restore_skips_a_window_reminimized_from_another_workspace(self):
        previous = dict(address="0x1", pid=4)
        snapshot = dict(workspace=1, layout="dwindle", minimized=[previous], windows=[previous])
        current = [dict(address="0x1", pid=4, workspace={"id":-99, "name":"special:forynarch-minimized"})]
        with patch.object(self.helper.subprocess, "check_output", return_value='{"workspace":1,"windows":[]}'):
            with patch.object(self.helper.subprocess, "run") as run, patch.object(self.helper, "query", return_value=current):
                with patch.object(self.helper, "dispatch") as dispatch, patch.object(self.helper, "hypr"):
                    self.helper.restore(snapshot, current)
                    run.assert_not_called()
                    dispatch.assert_not_called()


    def test_zero_spacing_region_edges_touch_without_empty_gap(self):
        monitor = dict(width=1280, height=800, scale=1, x=0, y=0, reserved=[0,64,0,0])
        style = dict(windowGap=0, screenMargin=0)
        self.assertEqual(self.helper.region_box(monitor,"left",style), (1,65,638,734))
        self.assertEqual(self.helper.region_box(monitor,"right",style), (641,65,638,734))


    def test_snap_and_pair_preserve_floating_or_tiled_mode(self):
        for action, floating, preferred, use_free in (("snap-top", True, False, True),
                ("snap-bottom", False, True, True), ("snap-top", False, False, False),
                ("pair-vertical", True, False, True), ("pair-vertical", False, False, False)):
            with self.subTest(action=action, floating=floating, preferred=preferred), tempfile.TemporaryDirectory() as directory:
                clients = [dict(address=f"0x{i}", pid=i, monitor=0, workspace={"id":1},
                                floating=floating, mapped=True, hidden=False, fullscreen=0,
                                at=[20,80], size=[400,300]) for i in range(1,4)]
                monitor = dict(id=0, width=1280, height=800, scale=1, x=0, y=0, reserved=[0,52,0,0])
                answers = {"activeworkspace":{"id":1}, "clients":clients, "monitors":[monitor], "activewindow":clients[0]}
                with patch.dict(os.environ, {"XDG_RUNTIME_DIR":directory}), \
                        patch.object(self.helper, "query", side_effect=lambda name: answers[name]), \
                        patch.object(self.helper, "floating_preference", return_value=preferred), \
                        patch.object(self.helper, "floating_snap") as free, patch.object(self.helper, "smart_snap") as native, \
                        patch.object(self.helper, "save") as save:
                    self.helper.apply(action, ["0x1","0x2"] if action.startswith("pair-") else ["0x1"])
                    self.assertEqual(free.called, use_free)
                    self.assertEqual(native.called, not use_free)
                    if action.startswith("snap-") and use_free:
                        self.assertEqual([c["address"] for c in free.call_args.args[2]], ["0x1"])
                        self.assertEqual([c["address"] for c in save.call_args.args[1]["windows"]], ["0x1"])
                    if action.startswith("pair-") and use_free:
                        self.assertEqual([c["address"] for c in save.call_args.args[1]["windows"]], ["0x1","0x2"])

    def test_complementary_positions_do_not_automatically_pair(self):
        with tempfile.TemporaryDirectory() as directory:
            clients = [dict(address=f"0x{i}", pid=i, monitor=0, workspace={"id":1}, floating=True,
                            mapped=True, hidden=False, fullscreen=0, at=[20,80], size=[400,300]) for i in (1,2)]
            answers = {"activeworkspace":{"id":1}, "clients":clients, "monitors":[dict(id=0,
                       width=1280, height=800, scale=1, x=0, y=0, reserved=[0,52,0,0])], "activewindow":clients[0]}
            with patch.dict(os.environ, {"XDG_RUNTIME_DIR":directory}), \
                    patch.object(self.helper, "query", side_effect=lambda name: answers[name]), \
                    patch.object(self.helper, "floating_preference", return_value=True), \
                    patch.object(self.helper, "layout_style", return_value=dict(windowGap=6, screenMargin=14)), \
                    patch.object(self.helper, "focus"), patch.object(self.helper, "dispatch") as dispatch:
                self.helper.apply("left", ["0x1"])
                dispatch.reset_mock()
                self.helper.apply("right", ["0x2"])
                self.assertTrue(dispatch.called)
                self.assertTrue(all(call.args[1] == "0x2" for call in dispatch.call_args_list))

    def test_floating_cells_never_overlap_or_leave_screen(self):
        for region in self.helper.REGIONS:
            for count in range(13):
                with self.subTest(region=region, count=count):
                    cells = [self.helper.REGIONS[region], *self.helper.floating_cells(region, count)]
                    self.assertEqual(len(cells), count+1)
                    for index, (x, y, w, h) in enumerate(cells):
                        self.assertTrue(0 <= x < x+w <= 1.0000001)
                        self.assertTrue(0 <= y < y+h <= 1.0000001)
                        for ox, oy, ow, oh in cells[index+1:]:
                            self.assertTrue(x+w <= ox+1e-9 or ox+ow <= x+1e-9 or y+h <= oy+1e-9 or oy+oh <= y+1e-9)

    def test_floating_snap_does_not_enter_native_layout(self):
        clients = [dict(address="0x1", floating=True), dict(address="0x2", floating=True)]
        monitor = dict(width=1280, height=800, scale=1, x=0, y=0, reserved=[0,52,0,0])
        with patch.object(self.helper, "layout_style", return_value=dict(windowGap=6, screenMargin=14)), \
                patch.object(self.helper, "dispatch") as dispatch, patch.object(self.helper, "focus"), \
                patch.object(self.helper, "hypr") as hypr:
            self.helper.floating_snap("top", clients[0], clients, monitor)
            self.assertEqual([call.args for call in dispatch.call_args_list if call.args[0] == "float"],
                             [("float", "0x1"), ("float", "0x2")])
            self.assertTrue(all(call.kwargs.get("action") == "on" for call in dispatch.call_args_list if call.args[0] == "float"))
            hypr.assert_not_called()

if __name__ == "__main__":
    unittest.main()
