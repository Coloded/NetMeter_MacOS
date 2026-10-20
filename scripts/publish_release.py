#!/usr/bin/env python3
"""Push a locally signed release over SSH; GitHub Actions publishes its assets."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from update_config import ROOT, load
from verify_update import verify


def git(*args, cwd=ROOT):
    return subprocess.check_output(['git', *args], cwd=cwd, text=True).strip()


def main():
    config = load(require_ready=True)
    version, build = config['version'], config['build']
    tag = 'v' + version
    if not re.fullmatch(r'v\d+\.\d+\.\d+', tag):
        raise SystemExit('Expected a stable semantic release version')
    if git('status', '--porcelain'):
        raise SystemExit('Commit source changes before publishing')
    commit = git('rev-parse', 'HEAD')
    if git('rev-parse', tag + '^{commit}') != commit:
        raise SystemExit('Release tag must point to the current source commit')
    remote = git('remote', 'get-url', 'origin')
    expected_remote = 'git@github.com:' + config['repository'] + '.git'
    if remote != expected_remote:
        raise SystemExit('Origin must use the configured GitHub SSH repository')
    directory = ROOT / f'dist/release-v{version}-build{build}'
    verify(directory, account=config['keychainAccount'],
           download_url=f'https://github.com/{config["repository"]}/releases/latest/download/NetMeter-stable.dmg',
           build=build, version=version)
    names = ('NetMeter-stable.dmg', 'appcast.xml', 'SHA256SUMS.txt')
    metadata = {'tag': tag, 'commit': commit, 'build': build,
                'sha256': {name: hashlib.sha256((directory / name).read_bytes()).hexdigest() for name in names}}
    existing = git('ls-remote', '--heads', 'origin', 'release-assets')
    with tempfile.TemporaryDirectory(prefix='publisher-', dir=ROOT / '.build') as temporary:
        work = Path(temporary)
        git('init', '-b', 'release-assets', cwd=work)
        git('remote', 'add', 'origin', remote, cwd=work)
        if existing:
            git('fetch', '--depth=1', 'origin', 'release-assets', cwd=work)
            git('checkout', '-B', 'release-assets', 'FETCH_HEAD', cwd=work)
        for setting in ('user.name', 'user.email'):
            git('config', setting, git('config', setting), cwd=work)
        assets = work / 'assets'
        assets.mkdir(exist_ok=True)
        for name in names:
            shutil.copyfile(directory / name, assets / name)
        workflow = work / '.github/workflows/publish-release.yml'
        workflow.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / '.github/workflows/publish-release.yml', workflow)
        shutil.copyfile(directory / 'release-notes.md', work / 'release-notes.md')
        (work / 'release.json').write_text(json.dumps(metadata, indent=2) + '\n')
        git('add', '.github/workflows/publish-release.yml', 'assets', 'release-notes.md', 'release.json', cwd=work)
        git('commit', '-m', 'Publish NetMeter ' + version, cwd=work)
        git('push', 'origin', 'HEAD:refs/heads/release-assets', cwd=work)
    print(f'Signed files sent over SSH. Publication status: https://github.com/{config["repository"]}/actions')


if __name__ == '__main__':
    main()
