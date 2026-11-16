#!/usr/bin/env python3
"""Reject overlapping builds; the OS releases the lock even after an interrupted build."""
import fcntl
from pathlib import Path
import subprocess
import sys


def main():
    if len(sys.argv) < 3:
        raise SystemExit('Usage: build_lock.py LOCK COMMAND [ARG ...]')
    path = Path(sys.argv[1])
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise SystemExit('Another NetMeter build is running. Wait for it before retrying.')
        return subprocess.run(sys.argv[2:], pass_fds=(lock.fileno(),)).returncode


if __name__ == '__main__':
    sys.exit(main())
