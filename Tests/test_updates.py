#!/usr/bin/env python3
"""Offline real-Sparkle signature regression using a disposable seed, no Keychain."""
from pathlib import Path
import base64
import os
import re
import subprocess
import sys
import tempfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from verify_update import TOOLS, verify

def run(*args):
    return subprocess.check_output(args, stderr=subprocess.STDOUT, text=True, timeout=20)

with tempfile.TemporaryDirectory(prefix="netmeter-update-qa-") as root:
    root = Path(root)
    key = root / "fixture.key"
    key.write_bytes(base64.b64encode(os.urandom(32)))
    key.chmod(0o600)
    archive = root / "NetMeter-stable.dmg"
    archive.write_bytes(b"fixture archive payload" * 1024)
    signature = run(str(TOOLS / "sign_update"), "--ed-key-file", str(key), "-p", str(archive)).strip()
    url = "https://github.com/fixture/repo/releases/download/v9.9.9/NetMeter-stable.dmg"
    feed = root / "appcast.xml"
    feed.write_text(f'''<?xml version="1.0"?><rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><title>QA</title><item><title>Fixture</title><enclosure url="{url}" length="{archive.stat().st_size}" sparkle:version="99" sparkle:shortVersionString="9.9.9" sparkle:edSignature="{signature}" /></item></channel></rss>''')
    run(str(TOOLS / "sign_update"), "--ed-key-file", str(key), str(feed))
    options = dict(private_key=key, download_url=url, build=99, version="9.9.9")
    verify(root, **options)
    checks = 1
    def rejects(**override):
        global checks
        try:
            verify(root, **(options | override))
        except (ValueError, subprocess.CalledProcessError):
            checks += 1
            return
        raise AssertionError("Invalid update accepted")
    original_feed = feed.read_bytes()
    feed.write_bytes(original_feed.replace(b"Fixture", b"Changed", 1))
    rejects()
    feed.write_bytes(original_feed)
    original_archive = archive.read_bytes()
    archive.write_bytes(original_archive[:-1] + bytes([original_archive[-1] ^ 1]))
    rejects()
    archive.write_bytes(original_archive)
    rejects(build=98)
    rejects(version="9.9.8")
    rejects(download_url=url.replace("v9.9.9", "v9.9.8"))
    archive.write_bytes(original_archive + b"trailing")
    rejects()
    try:
        verify(root, account=None, download_url=url, build=99, version="9.9.9")
    except ValueError:
        checks += 1
    else:
        raise AssertionError("Missing signing source must reject without Keychain fallback")
    print(f"PASS: {checks} real Sparkle signature/metadata regressions; temporary seed, no Keychain; archive is simulated bytes")
