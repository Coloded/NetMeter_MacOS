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
# Include keys built dynamically by graph menus and graph/window titles.
for key in [f"graph.{graph}" for graph in ("network", "memory", "cpu", "gpu", "disk")]:
    assert key in base, f"Missing dynamic key: {key}"
for language, catalog in catalogs.items():
    assert catalog.keys() == base.keys(), f"Missing translations: {language}"
    assert catalog["graph.grid"] == catalog["settings.grid"], f"Inconsistent grid wording: {language}"
    for key, text in catalog.items():
        if language != "en" and key not in {"app.name", "graph.cpu", "graph.gpu"}:
            assert text != base[key], f"Untranslated English text: {language}:{key}"
        assert text.strip(), f"Empty translation: {language}:{key}"
        formats = lambda value: re.findall(r"%(?:\d+\$)?(?:\.\d+)?[@df]", value.replace("%%", ""))
        assert formats(text) == formats(base[key]), f"Format mismatch: {language}:{key}"
for source in (ROOT / "Sources").rglob("*.swift"):
    if source.name.startswith("._"):
        continue
    for key in re.findall(r'\bL\("([^"\\]+)"', source.read_text()):
        assert key in base, f"Missing key {key} in {source.name}"
print(f"PASS: {len(base)} keys, four complete catalogs and matching format placeholders")
