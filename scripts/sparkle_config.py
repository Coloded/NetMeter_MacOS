#!/usr/bin/env python3
"""Single public pin for the official Sparkle distribution."""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent


def load():
    data = json.loads((ROOT / 'updates/sparkle.json').read_text())
    if not re.fullmatch(r'\d+\.\d+\.\d+', data['version']):
        raise ValueError('Invalid Sparkle version')
    if not re.fullmatch(r'[0-9a-f]{64}', data['sha256']):
        raise ValueError('Invalid Sparkle SHA-256')
    return data


def dependency_root():
    return ROOT / '.build/deps' / ('Sparkle-' + load()['version'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('field', choices=['version', 'sha256', 'directory'])
    args = parser.parse_args()
    print(str(dependency_root()) if args.field == 'directory' else load()[args.field])
