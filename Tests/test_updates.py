#!/usr/bin/env python3
"""Offline integration test of signed feeds and archives using this app's key."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import argparse
import plistlib
import subprocess
import tempfile
from copy_bundle import copy_bundle
from update_config import ROOT, load
from verify_update import TOOLS, verify


def run(*arguments):
    result = subprocess.run(arguments, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError((result.stdout + result.stderr)[-4000:])


parser = argparse.ArgumentParser(description="Локальная проверка подписей тестового обновления")
parser.add_argument("--dmg", action="store_true", help="Проверить DMG вместо ZIP")
args = parser.parse_args()
config = load()
if not config["publicEdKey"]:
    raise SystemExit("Сначала выполните scripts/setup_update_key.py")
if not (ROOT / ".build/staging/NetMeter.app/Contents/Info.plist").exists():
    raise SystemExit("Сначала выполните bash build.sh --no-install")

with tempfile.TemporaryDirectory(prefix="traffic-updater-test-") as temporary:
    temporary = Path(temporary)
    app = temporary / "NetMeter.app"
    copy_bundle(ROOT / ".build/staging/NetMeter.app", app)
    info_file = app / "Contents/Info.plist"
    info = plistlib.loads(info_file.read_bytes())
    info.update(CFBundleVersion="2", CFBundleShortVersionString="1.0.1",
                SUFeedURL="https://example.invalid/appcast.xml", SUPublicEDKey=config["publicEdKey"],
                SUEnableAutomaticChecks=False)
    info_file.write_bytes(plistlib.dumps(info))
    run("codesign", "--force", "--sign", "-", str(app))
    artifacts = temporary / "artifacts"
    artifacts.mkdir()
    archive = artifacts / ("NetMeter-stable.dmg" if args.dmg else "NetMeter-stable.zip")
    if args.dmg:
        payload = temporary / "payload"
        copy_bundle(app, payload / "NetMeter.app")
        (payload / "Applications").symlink_to("/Applications")
        run("hdiutil", "create", "-volname", "NetMeter updater test", "-fs", "HFS+", "-srcfolder", str(payload), "-format", "UDZO", str(archive))
        run("hdiutil", "verify", str(archive))
    else:
        run("ditto", "-c", "-k", "--keepParent", str(app), str(archive))
    (artifacts / "NetMeter-stable.md").write_text("# Local integration test\nSigned release notes.\n")
    run(str(TOOLS / "generate_appcast"), "--account", config["keychainAccount"],
        "--maximum-deltas", "0", "--maximum-versions", "1", "--download-url-prefix",
        "https://example.invalid/", "--embed-release-notes", str(artifacts))
    options = dict(account=config["keychainAccount"], download_url="https://example.invalid/" + archive.name,
                   build=2, version="1.0.1")
    verify(artifacts, **options)
    print("PASS: подписанная лента, архив и метаданные проходят проверку")

    def rejects():
        try:
            verify(artifacts, **options)
        except (ValueError, subprocess.CalledProcessError):
            return
        raise AssertionError("Изменённый файл был принят")

    feed = artifacts / "appcast.xml"
    original_feed = feed.read_bytes()
    feed.write_bytes(original_feed.replace(b"<title>", b"<title>tampered-", 1))
    rejects()
    feed.write_bytes(original_feed)
    print("PASS: изменение appcast.xml отвергается")

    original_archive = archive.read_bytes()
    changed = bytearray(original_archive)
    changed[-1] ^= 1
    archive.write_bytes(changed)
    rejects()
    print("PASS: изменение архива без изменения его размера отвергается")

if not config["repository"]:
    result = subprocess.run(["python3", "scripts/prepare_update.py"], cwd=ROOT, capture_output=True, text=True)
    assert result.returncode != 0 and "Обновления не подключены" in result.stderr
    print("PASS: выпуск без настроенного репозитория заблокирован")
