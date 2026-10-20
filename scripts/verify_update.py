#!/usr/bin/env python3
import argparse
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET
from update_config import ROOT, load

SPARKLE_NS = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
TOOLS = ROOT / ".build/deps/Sparkle-2.9.2/bin"


def verify(directory, *, account, download_url, build, version):
    directory = Path(directory)
    feed = directory / "appcast.xml"
    subprocess.run([str(TOOLS / "sign_update"), "--account", account, "--verify", str(feed)], check=True, capture_output=True)
    root = ET.parse(feed).getroot()
    items = root.findall("./channel/item")
    if len(items) != 1:
        raise ValueError("Лента должна содержать ровно один текущий выпуск")
    item = items[0]
    enclosure = item.find("enclosure")
    if enclosure is None:
        raise ValueError("В ленте отсутствует enclosure")
    found_build = enclosure.get(SPARKLE_NS + "version") or item.findtext(SPARKLE_NS + "version")
    found_version = enclosure.get(SPARKLE_NS + "shortVersionString") or item.findtext(SPARKLE_NS + "shortVersionString")
    if found_build != str(build) or found_version != version:
        raise ValueError("Версия или номер сборки в ленте не совпадают с приложением")
    if enclosure.get("url") != download_url:
        raise ValueError("Адрес архива в ленте не совпадает с настроенным репозиторием")
    archive = directory / download_url.rsplit("/", 1)[-1]
    if archive.stat().st_size != int(enclosure.get("length", "-1")):
        raise ValueError("Размер архива не совпадает с подписанной лентой")
    signature = enclosure.get(SPARKLE_NS + "edSignature")
    if not signature:
        raise ValueError("В ленте отсутствует EdDSA-подпись архива")
    subprocess.run([str(TOOLS / "sign_update"), "--account", account, "--verify", str(archive), signature], check=True, capture_output=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Проверить подписи и метаданные готового обновления")
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    config = load(require_ready=True)
    try:
        verify(args.directory, account=config["keychainAccount"],
               download_url=f'https://github.com/{config["repository"]}/releases/latest/download/NetMeter-stable.dmg',
               build=config["build"], version=config["version"])
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit("Проверка обновления не пройдена: " + str(error))
    print("Подписи ленты и архива, версия, размер и адрес обновления проверены.")
