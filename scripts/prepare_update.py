#!/usr/bin/env python3
"""Prepare a local signed release; never publish or upload anything."""
import hashlib
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
from copy_bundle import copy_bundle
from update_config import ROOT, load
from verify_update import TOOLS, verify


def main():
    config = load(require_ready=True)
    subprocess.run(["bash", "scripts/setup_sparkle.sh"], cwd=ROOT, check=True)
    account = config["keychainAccount"]
    public = subprocess.run([str(TOOLS / "generate_keys"), "--account", account, "-p"], check=True, capture_output=True, text=True).stdout.strip()
    if public != config["publicEdKey"]:
        raise ValueError("Ключ в Keychain не совпадает с публичным ключом приложения")
    notes = (ROOT / "updates/release-notes.md").read_text()
    if not notes.strip():
        raise ValueError("Заполните updates/release-notes.md")
    output = ROOT / "dist" / f'release-v{config["version"]}-build{config["build"]}'
    if output.exists():
        raise ValueError("Этот выпуск уже подготовлен. Для нового выпуска увеличьте номер сборки.")
    subprocess.run(["bash", "build.sh", "--no-install"], cwd=ROOT, check=True)
    app = ROOT / ".build/staging/NetMeter.app"
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    expected_feed = f'https://github.com/{config["repository"]}/releases/latest/download/appcast.xml'
    if info.get("SUFeedURL") != expected_feed or info.get("SUPublicEDKey") != public:
        raise ValueError("Собранное приложение содержит неверные настройки обновлений")
    with tempfile.TemporaryDirectory(prefix="release-", dir=ROOT / ".build") as temporary:
        temporary = Path(temporary)
        payload = temporary / "payload"
        copy_bundle(app, payload / "NetMeter.app")
        (payload / "Applications").symlink_to("/Applications")
        artifacts = temporary / "artifacts"
        artifacts.mkdir()
        image = artifacts / "NetMeter-stable.dmg"
        subprocess.run(["hdiutil", "create", "-volname", "NetMeter", "-fs", "HFS+", "-srcfolder", str(payload), "-format", "UDZO", str(image)], check=True)
        subprocess.run(["hdiutil", "verify", str(image)], check=True)
        (artifacts / "NetMeter-stable.md").write_text(notes)
        prefix = f'https://github.com/{config["repository"]}/releases/latest/download/'
        subprocess.run([str(TOOLS / "generate_appcast"), "--account", account,
                        "--maximum-deltas", "0", "--maximum-versions", "1",
                        "--download-url-prefix", prefix, "--embed-release-notes", str(artifacts)], check=True)
        verify(artifacts, account=account, download_url=prefix + image.name,
               build=config["build"], version=config["version"])
        manifest = []
        for name in ["NetMeter-stable.dmg", "appcast.xml"]:
            path = artifacts / name
            manifest.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {name}")
        (artifacts / "SHA256SUMS.txt").write_text("\n".join(manifest) + "\n")
        (artifacts / "release-notes.md").write_text(notes)
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(artifacts, output)
    print(f"Подписанный выпуск подготовлен: {output}")
    print("Файлы ещё не опубликованы в GitHub Releases.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit("Не удалось подготовить обновление: " + str(error))
