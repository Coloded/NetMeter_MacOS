#!/usr/bin/env python3
import subprocess
from update_config import ROOT, load, save

config = load()
tool = ROOT / ".build/deps/Sparkle-2.9.2/bin/generate_keys"
account = config["keychainAccount"]
result = subprocess.run([str(tool), "--account", account, "-p"], capture_output=True, text=True)
if result.returncode:
    created = subprocess.run([str(tool), "--account", account], capture_output=True, text=True)
    if created.returncode:
        raise SystemExit("Не удалось создать ключ обновлений в Keychain. " + created.stderr.strip())
    result = subprocess.run([str(tool), "--account", account, "-p"], capture_output=True, text=True, check=True)
key = result.stdout.strip()
if config["publicEdKey"] and config["publicEdKey"] != key:
    raise SystemExit("Ключ в конфигурации отличается от Keychain. Автоматическая замена запрещена.")
config["publicEdKey"] = key
save(config)
print("Ключ обновлений подготовлен в Keychain. В конфигурацию записан только публичный ключ.")
