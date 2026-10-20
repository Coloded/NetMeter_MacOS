#!/usr/bin/env python3
"""Copy code bundles preserving symlinks and modes, without filesystem metadata."""
import os
from pathlib import Path
import shutil
import sys


def copy_bundle(source, destination):
    source, destination = Path(source), Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    for entry in source.iterdir():
        if entry.name.startswith("._"):
            continue
        target = destination / entry.name
        if entry.is_symlink():
            if target.is_symlink() or target.is_file():
                target.unlink()
            os.symlink(os.readlink(entry), target)
        elif entry.is_dir():
            copy_bundle(entry, target)
        else:
            shutil.copyfile(entry, target)
            target.chmod(entry.stat().st_mode & 0o777)
    for entry in destination.rglob("._*"):
        if entry.is_file():
            entry.unlink()


if __name__ == "__main__":
    copy_bundle(sys.argv[1], sys.argv[2])
