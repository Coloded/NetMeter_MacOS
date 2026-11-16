#!/usr/bin/env python3
"""Exercise actual build-lock contention, exit propagation and parent interruption."""
from pathlib import Path
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "scripts/build_lock.py"


class BuildLockTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="netmeter-lock-qa-")
        self.directory = Path(self.temporary.name)
        self.lock = self.directory / "build.lock"
        self.children = []

    def tearDown(self):
        for pid in self.children:
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        self.temporary.cleanup()

    def command(self, code):
        return [sys.executable, str(RUNNER), str(self.lock), sys.executable, "-c", code]

    def start_holder(self):
        pidfile = self.directory / "holder.pid"
        release = self.directory / "release"
        code = f"import os,time,pathlib; pathlib.Path({str(pidfile)!r}).write_text(str(os.getpid())); "
        code += f"\nwhile not pathlib.Path({str(release)!r}).exists(): time.sleep(0.02)"
        process = subprocess.Popen(self.command(code), stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        deadline = time.monotonic() + 4
        while not pidfile.exists() and process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.02)
        self.assertTrue(pidfile.exists(), "fixture holder did not acquire lock")
        pid = int(pidfile.read_text())
        self.children.extend([pid, process.pid])
        return process, pid, release

    def assertContended(self):
        result = subprocess.run(self.command("raise SystemExit(0)"), capture_output=True, text=True, timeout=3)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Another NetMeter build is running", result.stderr)

    def test_overlap_is_rejected_then_normal_exit_releases_lock(self):
        process, _, release = self.start_holder()
        self.assertContended()
        release.touch()
        self.assertEqual(process.wait(timeout=3), 0)
        process.stderr.close()
        result = subprocess.run(self.command("raise SystemExit(0)"), timeout=3)
        self.assertEqual(result.returncode, 0)

    def test_child_failure_is_propagated_and_lock_is_reusable(self):
        result = subprocess.run(self.command("raise SystemExit(7)"), timeout=3)
        self.assertEqual(result.returncode, 7)
        self.assertEqual(subprocess.run(self.command("raise SystemExit(0)"), timeout=3).returncode, 0)

    def test_killed_parent_does_not_unlock_live_build_child(self):
        process, child, release = self.start_holder()
        process.kill()
        process.wait(timeout=3)
        self.assertEqual(os.kill(child, 0), None)
        self.assertContended()
        release.touch()
        deadline = time.monotonic() + 3
        result = None
        while time.monotonic() < deadline:
            result = subprocess.run(self.command("raise SystemExit(0)"), capture_output=True, timeout=3)
            if result.returncode == 0:
                break
            time.sleep(0.02)
        process.stderr.close()
        self.assertIsNotNone(result)
        self.assertEqual(result.returncode, 0, "lock remained after the actual child exited")


if __name__ == "__main__":
    unittest.main(verbosity=2)
