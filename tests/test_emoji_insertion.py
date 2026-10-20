"""Keep emoji insertion in the chosen application and use terminal paste keys."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name=="posix" and shutil.which("jq"),"Arch shell tools required")
class Insertion(unittest.TestCase):
    def run_insert(self, *, changed=False, popup=False, monitor=0, no_window=False):
        with tempfile.TemporaryDirectory() as temporary:
            base=Path(temporary);binary=base/"bin";binary.mkdir()
            sources={
                "hyprctl":'''import json,os,sys
from pathlib import Path
base=Path(os.environ["FORYNARCH_TEST_DIR"])
if sys.argv[1:]==["-j","activewindow"]:
    counter=base/"counter";n=int(counter.read_text())+1 if counter.exists() else 1;counter.write_text(str(n))
    value={} if os.environ.get("NO_WINDOW")=="1" else dict(address="0x123" if n==1 or os.environ.get("CHANGED")!="1" else "0x456",monitor=int(os.environ["MONITOR"]),**{"class":"foot"})
    print(json.dumps(value))
elif sys.argv[1:]==["-j","monitors"]:print('[{"id":0,"focused":true}]')
elif sys.argv[1]=="dispatch":
    with (base/"dispatch").open("a") as out:out.write(sys.argv[2]+"\\n")
''',
                "wl-copy":'import os,sys;from pathlib import Path;Path(os.environ["FORYNARCH_TEST_DIR"],"clipboard").write_text(sys.stdin.read())',
                "qs":'import json,os;print(json.dumps({"settingsOpen":os.environ.get("POPUP")=="1"}))'
            }
            for name,source in sources.items():
                path=binary/name;path.write_text("#!"+sys.executable+"\n"+source+"\n");path.chmod(0o755)
            helper=binary/"forynarch-hotkey"
            helper.write_text('#!/bin/bash\nexec bash "'+str(ROOT/"scripts/forynarch-hotkey.sh")+'" "$@"\n');helper.chmod(0o755)
            env={**os.environ,"PATH":str(binary)+":"+os.environ["PATH"],"FORYNARCH_TEST_DIR":str(base),"CHANGED":str(int(changed)),"POPUP":str(int(popup)),"MONITOR":str(monitor),"NO_WINDOW":str(int(no_window))}
            result=subprocess.run(["bash",str(ROOT/"scripts/forynarch-insert.sh"),"paste"],input="💙",text=True,capture_output=True,env=env)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual((base/"clipboard").read_text(),"💙")
            return (base/"dispatch").read_text() if (base/"dispatch").exists() else ""

    def test_terminal_uses_control_shift_v(self):
        dispatch=self.run_insert()
        self.assertIn('mods="CTRL SHIFT",key="V"',dispatch)
        self.assertIn('window="address:0x123"',dispatch)

    def test_changed_focus_open_popup_other_monitor_and_empty_desktop_only_copy(self):
        for changes in [dict(changed=True),dict(popup=True),dict(monitor=1),dict(no_window=True)]:
            with self.subTest(changes=changes):self.assertEqual(self.run_insert(**changes),"")
