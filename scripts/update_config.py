#!/usr/bin/env python3
"""Public updater settings only. Private EdDSA keys stay in the login Keychain."""
import argparse
import base64
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = ROOT / "updates/config.json"


def repository_name(value):
    value = value.strip().removeprefix("https://github.com/").removesuffix("/").removesuffix(".git")
    if value and (not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+", value) or value.split("/")[1] in (".", "..")):
        raise ValueError("Укажите GitHub-репозиторий как OWNER/REPO или https://github.com/OWNER/REPO")
    return value


def validate(config, require_ready=False):
    config["repository"] = repository_name(config["repository"])
    if not re.fullmatch(r"\d+(?:\.\d+){0,2}", config["version"]):
        raise ValueError("Некорректная версия: ожидается 1.0.0")
    if type(config["build"]) is not int or config["build"] < 1:
        raise ValueError("Номер сборки должен быть положительным целым числом")
    key = config["publicEdKey"]
    if key and len(base64.b64decode(key, validate=True)) != 32:
        raise ValueError("Публичный Ed25519-ключ должен содержать 32 байта")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", config["keychainAccount"]):
        raise ValueError("Некорректное имя ключа в Keychain")
    if require_ready and not (config["repository"] and key):
        raise ValueError("Обновления не подключены: нужны repository и publicEdKey в updates/config.json")
    return config


def load(require_ready=False):
    return validate(json.loads(CONFIG_PATH.read_text()), require_ready)


def save(config):
    validate(config)
    CONFIG_PATH.write_text(json.dumps(config, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Настройки GitHub Releases и публичного ключа обновлений")
    parser.add_argument("--repository")
    parser.add_argument("--public-key")
    parser.add_argument("--version")
    parser.add_argument("--build", type=int)
    args = parser.parse_args()
    config = load()
    if args.build is not None and args.build < config["build"]:
        parser.error("Номер сборки не может уменьшаться")
    if args.version is not None and args.version != config["version"] and (args.build is None or args.build <= config["build"]):
        parser.error("Для новой версии увеличьте номер сборки через --build")
    for argument, key in [(args.repository, "repository"), (args.public_key, "publicEdKey"), (args.version, "version"), (args.build, "build")]:
        if argument is not None:
            config[key] = argument
    try:
        save(config)
    except (ValueError, TypeError) as error:
        parser.error(str(error))
    print("Настройки обновлений сохранены." if config["repository"] else "Репозиторий пока не задан; обновления отключены.")
