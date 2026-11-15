#!/usr/bin/env python3
"""App canary: does this engine still build every real application? (the Administrator, 2026-11-15)

RADE's own tests use a sample app, so a change to the contract between RADE and the apps (manifest fields, check ids,
build rules) could pass here and break an app later, at its lock change. This check finds that before a release.

For each application in apps.json it makes a fresh, shallow copy of the app repository's main branch in a temporary
folder (read-only: nothing is pushed, the app repository is never changed, and no RADE checkout of the app is used), then:
  1. checks the app's manifest with scripts/check_manifest.py (the schema in this checkout);
  2. builds every bundle with the engine in this checkout.
If 1 or 2 fails, it builds the same copy with the engine the app has locked (its rade.lock.json beside the manifest).
  - The locked engine builds it: this checkout breaks the app. FAIL.
  - The locked engine fails too (or the app has no lock file): the app is broken by itself. NOTE, not counted: RADE
    cannot fix it, and its own checks must not fail for it.
  - The app has a lock but its engine cannot be read from this repository's history: FAIL (nothing to compare with must
    never look like a pass).
It runs none of the app's code: the engine only reads the app's files. Paths in a manifest that leave the copy are refused.
An app repository that cannot be fetched is a FAIL (no skip): the check needs network access to github.com.
Usage: python3 scripts/check_apps.py     Pass = last line "APPS apps=N fail=0".
"""
import json, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENGINE = ROOT / 'engine/rade_build.py'


def run(cmd, cwd=None):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=300)
    return r.returncode, (r.stdout + r.stderr).strip()


def tail(text, n=6):
    return '\n'.join('    ' + l[:220] for l in text.splitlines()[-n:])


def unsafe_paths(manifest):
    """Manifest paths that are absolute or leave the app folder (the build would read or write outside the copy)."""
    bad = []
    for b in manifest.get('bundles', []):
        for p in [b.get('out', '')] + [f.get('src', '') for f in b.get('files', []) + b.get('fetch', [])]:
            if p and (Path(p).is_absolute() or '..' in Path(p).parts or '\\' in p):
                bad.append(p)
    return bad


def locked_engine(app_dir, manifest_rel, tmp):
    """The engine the app has locked, taken from this repository's history by commit.
    None when the app has no lock file; LookupError when it has one that cannot be used."""
    lock_file = app_dir / Path(manifest_rel).parent / 'rade.lock.json'
    if not lock_file.is_file():
        return None
    try:
        lock = json.loads(lock_file.read_text())
        commit, files = lock['commit'], lock['files']
        if not all(c in '0123456789abcdef' for c in commit) or len(commit) != 40:
            raise LookupError('the lock names no commit id')
        if run(['git', 'cat-file', '-e', commit + '^{commit}'], ROOT)[0] != 0:
            run(['git', 'fetch', '-q', 'origin', commit], ROOT)
        home = tmp / ('engine-' + commit[:12])
        for rel in files:
            if Path(rel).is_absolute() or '..' in Path(rel).parts:
                raise LookupError('the lock has a bad file path')
            r = subprocess.run(['git', 'show', commit + ':' + rel], cwd=ROOT, capture_output=True, timeout=60)
            if r.returncode != 0:
                raise LookupError('commit %s (file %s) is not in this clone and could not be fetched' % (commit[:12], rel))
            (home / rel).parent.mkdir(parents=True, exist_ok=True)
            (home / rel).write_bytes(r.stdout)
        return home / lock['engine']
    except (ValueError, KeyError, TypeError, OSError) as e:
        raise LookupError('the lock cannot be read (%s)' % type(e).__name__)


def check(app, tmp):
    """Returns (status, lines): status is 'ok', 'fail' (this checkout breaks the app) or 'note' (the app is broken by itself)."""
    repo, manifest_rel = app['repo'], app['manifest']
    d = tmp / repo.replace('/', '__')
    code, out = run(['git', 'clone', '-q', '--depth', '1', 'https://github.com/%s.git' % repo, str(d)])
    if code != 0:
        return 'fail', ['cannot fetch the repository (this check needs network access to github.com):', tail(out, 3)]
    try:
        manifest = json.loads((d / manifest_rel).read_text())
    except (OSError, ValueError) as e:
        return 'note', ['the manifest %s cannot be read on its main branch (%s)' % (manifest_rel, type(e).__name__)]
    bad = unsafe_paths(manifest) if isinstance(manifest, dict) else ['(the manifest is not an object)']
    if bad:
        return 'note', ['the manifest has paths that leave the app folder, so it was not built: %s' % ', '.join(bad[:3])]
    base = tmp / (d.name + '__locked')
    shutil.copytree(d, base)   # the copy for the locked engine, made before this engine writes its bundles
    problems = []
    code, out = run([sys.executable, str(ROOT / 'scripts/check_manifest.py'), str(d / manifest_rel)])
    if code != 0:
        problems.append('scripts/check_manifest.py:\n' + tail(out))
    code, out = run([sys.executable, '-B', str(ENGINE), '--app-root', str(d), '--manifest', manifest_rel])
    built = out.count('BUILT ')
    if code != 0:
        problems.append('engine/rade_build.py:\n' + tail(out))
    if not problems:
        return 'ok', ['%d bundle(s) built with this engine' % built]
    try:
        old = locked_engine(base, manifest_rel, tmp)
    except LookupError as e:
        return 'fail', ['this checkout does not build the app, and the app\'s locked engine cannot be used to compare (%s):' % e] + problems
    if old is None:
        return 'note', ['this checkout does not build the app, and the app has no lock file, so there is nothing to compare with:'] + problems
    code, out = run([sys.executable, '-B', str(old), '--app-root', str(base), '--manifest', manifest_rel])
    if code != 0:
        return 'note', ['the app does not build with its own locked engine either (the app is broken by itself):', tail(out, 3)]
    return 'fail', ['the app builds with its locked engine but NOT with this checkout. This change breaks the app:'] + problems


def main():
    apps = json.loads((ROOT / 'apps.json').read_text())['apps']
    fails = 0
    with tempfile.TemporaryDirectory() as t:
        for app in apps:
            status, lines = check(app, Path(t))
            print('%s %s (%s)' % ({'ok': 'PASS', 'fail': 'FAIL', 'note': 'NOTE'}[status], app['repo'], app['manifest']))
            for l in lines:
                print('  ' + l if not l.startswith('    ') else l)
            fails += status == 'fail'
    print('APPS apps=%d fail=%d' % (len(apps), fails))
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
