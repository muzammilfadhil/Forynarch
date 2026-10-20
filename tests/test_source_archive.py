import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("source_archive", ROOT / "scripts/source_archive.py")
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


class SourceTransferContract(unittest.TestCase):
    def test_native_code_transfers_without_compiler_artifacts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            native = root / "native/agent"
            native.mkdir(parents=True)
            (native / "main.cpp").write_text("int main() {return 0;}")
            (native / "agent.pro").write_text("SOURCES += main.cpp")
            (native / "main.o").write_bytes(b"object")
            (native / "forynarch-bluetooth-pair").write_bytes(b"binary")
            output = root / "source.zip"
            module.archive_source(root, output)
            with zipfile.ZipFile(output) as archive:
                self.assertEqual(set(archive.namelist()), {"native/agent/main.cpp", "native/agent/agent.pro"})

    def test_source_only_transfer(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in module.ROOT_FILES:
                (root / name).write_text("source", encoding="utf-8")
            (root / "scripts/__pycache__").mkdir(parents=True)
            (root / "out").mkdir()
            (root / "scripts/helper.py").write_text("pass", encoding="utf-8")
            (root / "scripts/__pycache__/helper.pyc").write_bytes(b"cache")
            (root / "scripts/.env").write_text("dummy", encoding="utf-8")
            (root / "scripts/id_ed25519").write_text("dummy", encoding="utf-8")
            (root / "out/generated.iso").write_bytes(b"generated")
            (root / "config/shaders").mkdir(parents=True)
            (root / "config/shaders/glass.frag.qsb").write_bytes(b"generated shader")
            output = root / "out/source.zip"
            module.archive_source(root, output)
            with zipfile.ZipFile(output) as archive:
                names = set(archive.namelist())
            self.assertEqual(names, set(module.ROOT_FILES) | {"scripts/helper.py"})


if __name__ == "__main__":
    unittest.main()
