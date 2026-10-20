#!/usr/bin/env python3
"""Check catalog coverage and format placeholders, including dynamic Swift keys."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
languages = ("en", "ru", "ar", "zh-Hans")
catalogs = {}
pattern = re.compile(r'("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*")\s*;')
for language in languages:
    source = (ROOT / f"Resources/Localization/{language}.lproj/Localizable.strings").read_text()
    entries = pattern.findall(source)
    catalog = {json.loads(k): json.loads(v) for k, v in entries}
    assert len(catalog) == len(entries), f"Duplicate keys: {language}"
    catalogs[language] = catalog
base = catalogs["en"]
for language, catalog in catalogs.items():
    assert catalog.keys() == base.keys(), f"Missing translations: {language}"
    for key, text in catalog.items():
        assert text.strip(), f"Empty translation: {language}:{key}"
        formats = lambda value: re.findall(r"%(?:\d+\$)?(?:\.\d+)?[@df]", value.replace("%%", ""))
        assert formats(text) == formats(base[key]), f"Format mismatch: {language}:{key}"
for source in (ROOT / "Sources").rglob("*.swift"):
    if source.name.startswith("._"):
        continue
    for key in re.findall(r'\bL\("([^"\\]+)"', source.read_text()):
        assert key in base, f"Missing key {key} in {source.name}"
print(f"PASS: {len(base)} keys, four complete catalogs and matching format placeholders")
