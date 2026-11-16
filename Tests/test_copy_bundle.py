#!/usr/bin/env python3
"""Bundle replacement tests confined to temporary fixture directories."""
import importlib.util
from pathlib import Path
import os
import stat
import sys
import tempfile
import unittest
from unittest import mock

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("netmeter_copy_bundle", ROOT / "scripts/copy_bundle.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class BundleCopyTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="netmeter-copy-qa-")
        self.root = Path(self.temporary.name)
        self.source = self.root / "source"
        self.destination = self.root / "destination"
        self.outside = self.root / "outside"
        self.source.mkdir()
        self.destination.mkdir()
        self.outside.mkdir()
        (self.outside / "sentinel").write_text("untouched")

    def tearDown(self):
        self.temporary.cleanup()

    def assertOutsideSafe(self):
        self.assertEqual((self.outside / "sentinel").read_text(), "untouched")
        self.assertEqual(sorted(p.name for p in self.outside.iterdir()), ["sentinel"])

    def test_removes_stale_nested_files(self):
        (self.source / "Resources").mkdir()
        (self.source / "Resources/new.txt").write_text("new")
        (self.destination / "Resources").mkdir()
        (self.destination / "Resources/obsolete.txt").write_text("stale")
        (self.destination / "removed-directory").mkdir()
        (self.destination / "removed-directory/stale").write_text("stale")
        module.copy_bundle(self.source, self.destination)
        self.assertEqual((self.destination / "Resources/new.txt").read_text(), "new")
        self.assertFalse((self.destination / "Resources/obsolete.txt").exists())
        self.assertFalse((self.destination / "removed-directory").exists())

    def test_directory_replaces_destination_symlink_without_following(self):
        (self.source / "Resources").mkdir()
        (self.source / "Resources/new.txt").write_text("new")
        (self.destination / "Resources").symlink_to(self.outside, target_is_directory=True)
        module.copy_bundle(self.source, self.destination)
        self.assertFalse((self.destination / "Resources").is_symlink())
        self.assertEqual((self.destination / "Resources/new.txt").read_text(), "new")
        self.assertOutsideSafe()

    def test_file_replaces_destination_symlink_without_following(self):
        (self.source / "file").write_text("replacement")
        (self.destination / "file").symlink_to(self.outside / "sentinel")
        module.copy_bundle(self.source, self.destination)
        self.assertFalse((self.destination / "file").is_symlink())
        self.assertEqual((self.destination / "file").read_text(), "replacement")
        self.assertOutsideSafe()

    def test_symlink_replaces_destination_directory_and_stays_relative(self):
        (self.source / "Current").symlink_to("Versions/A", target_is_directory=True)
        (self.destination / "Current").mkdir()
        (self.destination / "Current/obsolete").write_text("stale")
        module.copy_bundle(self.source, self.destination)
        self.assertTrue((self.destination / "Current").is_symlink())
        self.assertEqual(os.readlink(self.destination / "Current"), "Versions/A")

    def test_file_and_directory_type_replacement(self):
        (self.source / "directory").mkdir()
        (self.source / "directory/new").write_text("new")
        (self.source / "plain").write_text("plain")
        (self.destination / "directory").write_text("old file")
        (self.destination / "plain").mkdir()
        module.copy_bundle(self.source, self.destination)
        self.assertTrue((self.destination / "directory").is_dir())
        self.assertEqual((self.destination / "plain").read_text(), "plain")

    def test_root_destination_symlink_does_not_write_outside(self):
        self.destination.rmdir()
        self.destination.symlink_to(self.outside, target_is_directory=True)
        (self.source / "new.txt").write_text("new")
        try:
            module.copy_bundle(self.source, self.destination)
        except (ValueError, OSError):
            pass  # Rejecting a symlink root is also a safe contract.
        self.assertOutsideSafe()

    def test_executable_replacement_preserves_held_open_old_inode(self):
        # Simulate an old executable retained by a running process/kernel vnode cache.
        source = self.source / "NetMeter"
        target = self.destination / "NetMeter"
        source.write_bytes(b"new executable payload")
        source.chmod(0o755)
        target.write_bytes(b"old executable payload")
        with target.open("rb") as retained:
            old_inode = os.fstat(retained.fileno()).st_ino
            module.copy_bundle(self.source, self.destination)
            self.assertEqual(retained.read(), b"old executable payload",
                             "an open old executable must never be modified in place")
            self.assertEqual(target.read_bytes(), b"new executable payload")
            self.assertNotEqual(target.stat().st_ino, old_inode,
                                "replacement path must name a newly installed inode")
            self.assertTrue(target.stat().st_mode & stat.S_IXUSR)
        self.assertEqual(sorted(p.name for p in self.destination.iterdir()), ["NetMeter"],
                         "atomic-copy temporary sibling must not remain")

    def test_failed_copy_preserves_old_file_and_cleans_temporary_sibling(self):
        (self.source / "NetMeter").write_bytes(b"new payload")
        target = self.destination / "NetMeter"
        target.write_bytes(b"old payload")
        inode = target.stat().st_ino
        def partial_copy(source, temporary):
            Path(temporary).write_bytes(b"partial")
            raise OSError("fixture copy interrupted")
        with mock.patch.object(module.shutil, "copyfile", side_effect=partial_copy):
            with self.assertRaises(OSError):
                module.copy_bundle(self.source, self.destination)
        self.assertEqual(target.read_bytes(), b"old payload")
        self.assertEqual(target.stat().st_ino, inode)
        self.assertEqual(sorted(p.name for p in self.destination.iterdir()), ["NetMeter"])

    def test_modes_and_appledouble(self):
        executable = self.source / "binary"
        executable.write_text("#!/bin/sh\nexit 0\n")
        executable.chmod(0o755)
        (self.source / "._binary").write_text("metadata")
        (self.destination / "._old").write_text("stale metadata")
        module.copy_bundle(self.source, self.destination)
        self.assertTrue((self.destination / "binary").stat().st_mode & stat.S_IXUSR)
        self.assertFalse((self.destination / "._binary").exists())
        self.assertFalse((self.destination / "._old").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
