#!/usr/bin/env python3
"""Synchronize an owned bundle destination without following stale symlinks."""
import os
from pathlib import Path
import shutil
import sys
import tempfile


def remove(path):
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.exists():
        shutil.rmtree(path)


def copy_bundle(source, destination):
    source, destination = Path(source), Path(destination)
    source_real, destination_real = source.resolve(), destination.resolve()
    if source_real == destination_real or source_real in destination_real.parents or destination_real in source_real.parents:
        raise ValueError('Source and destination bundles must be separate, non-nested directories')
    if not source.is_dir() or source.is_symlink():
        raise ValueError('Source must be a real bundle directory')
    _sync(source, destination)


def _sync(source, destination):
    if destination.is_symlink() or (destination.exists() and not destination.is_dir()):
        remove(destination)
    destination.mkdir(parents=True, exist_ok=True)
    entries = [entry for entry in source.iterdir() if not entry.name.startswith('._')]
    names = {entry.name for entry in entries}
    for old in destination.iterdir():
        if old.name not in names:
            remove(old)
    for entry in entries:
        target = destination / entry.name
        if entry.is_symlink():
            remove(target)
            os.symlink(os.readlink(entry), target)
        elif entry.is_dir():
            _sync(entry, target)
        else:
            if target.is_symlink() or target.is_dir():
                remove(target)
            # Replacing the inode avoids stale executable/signature mappings on
            # macOS after an installed binary has already been launched.
            descriptor, temporary_name = tempfile.mkstemp(prefix='.bundle-copy-', dir=destination)
            os.close(descriptor)
            temporary = Path(temporary_name)
            try:
                shutil.copyfile(entry, temporary)
                temporary.chmod(entry.stat().st_mode & 0o777)
                os.replace(temporary, target)
            finally:
                temporary.unlink(missing_ok=True)
    destination.chmod(source.stat().st_mode & 0o777)


if __name__ == '__main__':
    copy_bundle(sys.argv[1], sys.argv[2])
