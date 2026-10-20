#!/usr/bin/env python3
import plistlib
import sys
from pathlib import Path
from update_config import ROOT, load

config = load()
info = plistlib.loads((ROOT / "Resources/Info.plist").read_bytes())
info["CFBundleShortVersionString"] = config["version"]
info["CFBundleVersion"] = str(config["build"])
ready = bool(config["repository"] and config["publicEdKey"])
info["SUEnableAutomaticChecks"] = ready
if config["publicEdKey"]:
    info["SUPublicEDKey"] = config["publicEdKey"]
if config["repository"]:
    info["SUFeedURL"] = f'https://github.com/{config["repository"]}/releases/latest/download/appcast.xml'
Path(sys.argv[1]).write_bytes(plistlib.dumps(info, sort_keys=False))
