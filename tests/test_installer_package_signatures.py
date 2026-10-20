"""Exercise the executor's filename guard with real Arch epoch names."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

@unittest.skipUnless(shutil.which("bash"), "Bash is required; run in the Arch builder")
class SignedPackageFilenameTests(unittest.TestCase):
    def test_epoch_names_and_unsafe_paths_use_the_actual_executor_guard(self):
        source = (ROOT / "scripts/install-target.sh").read_text()
        guard = next(line.strip().removesuffix(" || {") for line in source.splitlines() if '[[ "$filename" =~' in line)
        examples = {
            "discord-1:1.0.162-1-x86_64.pkg.tar.zst": True,
            "go-2:1.27.2-1-x86_64.pkg.tar.zst": True,
            "flatpak-1:1.18.4-2-x86_64.pkg.tar.zst": True,
            "git-2.56.0-1-x86_64.pkg.tar.zst": True,
            "legacy-1-1-any.pkg.tar.xz": True,
            "../escape.pkg.tar.zst": False,
            "/tmp/escape.pkg.tar.zst": False,
            "name/path.pkg.tar.zst": False,
            ".hidden.pkg.tar.zst": False,
            "name;command.pkg.tar.zst": False,
            "name$(command).pkg.tar.zst": False,
            "name with space.pkg.tar.zst": False,
        }
        for filename, accepted in examples.items():
            with self.subTest(filename=filename):
                result = subprocess.run(["bash", "-c", 'filename=$1;signature=$2;'+guard, "fixture", filename, "signed"], capture_output=True)
                self.assertEqual(result.returncode == 0, accepted, result.stderr)
        result = subprocess.run(["bash", "-c", 'filename=$1;signature=$2;'+guard, "fixture", "git-2-1-any.pkg.tar.zst", ""], capture_output=True)
        self.assertNotEqual(result.returncode, 0)

@unittest.skipUnless(shutil.which("bash"), "Bash is required")
class FlatpakRetryTests(unittest.TestCase):
    def test_only_transient_network_errors_retry_the_selected_transaction_once(self):
        source = (ROOT / "scripts/install-target.sh").read_text()
        start = source.index("    for flatpak_attempt in 1 2;do")
        end = source.index("\n    done", start) + len("\n    done")
        loop = source[start:end]
        fixture = '''set -euo pipefail
state=$1;kind=$2;mountroot=/fixture-only;username=fixture;flatpak_apps=(com.fixture.App)
printf '0' > "$state/count"
target_flatpak() {
    local count
    count=$(cat "$state/count");count=$((count+1));printf '%s' "$count" > "$state/count"
    if [[ "$kind" == transient && "$count" == 2 ]];then return 0;fi
    if [[ "$kind" == permission ]];then echo 'Permission denied';elif [[ "$kind" == sandbox ]];then echo 'bwrap: No permissions to create a new namespace';else echo 'Error [6] Could not resolve hostname';fi
    return 1
}
sleep() { :; }
'''
        for kind, expected_code, attempts in (("transient", 0, 2), ("persistent", 1, 2), ("permission", 1, 1), ("sandbox", 1, 1)):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as temporary:
                result = subprocess.run(["bash", "-c", fixture + loop, "fixture", temporary, kind], capture_output=True, text=True)
                self.assertEqual(result.returncode, expected_code, result.stderr)
                self.assertEqual(int((Path(temporary) / "count").read_text()), attempts)

@unittest.skipUnless(all(shutil.which(tool) for tool in ("pacman", "repo-add", "bsdtar")), "Requires Arch package tools")
class CachedTransactionTests(unittest.TestCase):
    def test_actual_planner_survives_warm_cache_but_rejects_identity_changes(self):
        source = (ROOT / "scripts/install-target.sh").read_text()
        start = source.index('if [[ ${#optional[@]} -gt 0 ]]; then')
        initial = source[start:source.index("\nelse\n", start)] + "\nfi\n"
        end = source.index('> "$state/rechecked-transaction.txt"')
        start = source.rfind('  pacman --config', 0, end)
        recheck = source[start:source.index("\n  }", end) + len("\n  }")]
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repo = root / "repo"; repo.mkdir()
            package_root = root / "package"; package_root.mkdir()
            (package_root / ".PKGINFO").write_text("pkgname = forynarch-cache-fixture\npkgbase = forynarch-cache-fixture\npkgver = 1.0-1\npkgdesc = Disposable cache regression\nbuilddate = 1\npackager = QA Fixture\nsize = 1\narch = any\nlicense = MIT\n")
            package = repo / "forynarch-cache-fixture-1.0-1-any.pkg.tar.zst"
            subprocess.run(["bsdtar", "--zstd", "-cf", str(package), "-C", str(package_root), ".PKGINFO"], check=True, capture_output=True)
            subprocess.run(["repo-add", "-q", str(repo / "fixture.db.tar.gz"), str(package)], check=True, capture_output=True)
            state = root / "state"; state.mkdir()
            for folder in ("db/local", "db/sync", "cache"):
                (state / folder).mkdir(parents=True, exist_ok=True)
            shutil.copyfile(repo / "fixture.db", state / "db/sync/fixture.db")
            (root / "pacman.conf").write_text("[options]\nArchitecture = auto\nSigLevel = Never\n[fixture]\nServer = file://" + str(repo) + "\n")
            prefix = 'set -euo pipefail\nbundle=$1;state=$2;optional=(forynarch-cache-fixture)\n'
            def execute(block):
                return subprocess.run(["bash", "-c", prefix + block, "fixture", str(root), str(state)], capture_output=True, text=True)
            planned = execute(initial)
            self.assertEqual(planned.returncode, 0, planned.stderr)
            before_size = (state / "optional-transaction.txt").read_text()
            self.assertNotEqual(before_size.split()[2], "0")
            identity = (state / "package-identities.txt").read_text()
            shutil.copyfile(package, state / "cache" / package.name)
            base = ["pacman", "--config", str(root / "pacman.conf"), "--dbpath", str(state / "db"), "--cachedir", str(state / "cache")]
            cached_size = subprocess.check_output(base + ["-Sp", "--needed", "--print-format", "%n %v %s", "--", "forynarch-cache-fixture"], text=True)
            self.assertEqual(cached_size.split()[2], "0")
            accepted = execute(recheck)
            self.assertEqual(accepted.returncode, 0, accepted.stdout + accepted.stderr)
            self.assertEqual((state / "rechecked-transaction.txt").read_text(), identity)
            fields = identity.split()
            for index, replacement in ((0, "another-package"), (1, "2.0-1"), (2, "0" * 64)):
                changed = list(fields); changed[index] = replacement
                (state / "package-identities.txt").write_text(" ".join(changed) + "\n")
                with self.subTest(field=index):
                    self.assertNotEqual(execute(recheck).returncode, 0)

if __name__ == "__main__":
    unittest.main()
