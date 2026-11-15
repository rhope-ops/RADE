#!/usr/bin/env python3
"""App canary: does this engine still build every real application? (the Administrator, 2026-11-15)

RADE's own tests use a sample app, so a change to the contract between RADE and the apps (manifest fields, check ids,
build rules) could pass here and break an app later, at its lock change. This check finds that before a release.

For each application in apps.json it makes a fresh, shallow copy of the app repository's main branch in a temporary
folder (read-only: nothing is pushed, the app repository is never changed, and no RADE checkout of the app is used), then:
  1. checks the app's manifest with scripts/check_manifest.py (the schema in this checkout);
  2. builds every bundle with the engine in this checkout.
If 1 or 2 fails, it does the same with what the app has locked (its rade.lock.json beside the manifest): the schema at the
locked commit, and the locked engine, both taken from this repository's history.
  - The locked schema and engine accept it: this checkout breaks the app. FAIL.
  - They do not (or the app has no lock file): the app is broken by itself. NOTE, not counted: RADE cannot fix it, and
    its own checks must not fail for it.
  - The app has a lock but its engine cannot be read from this repository's history: FAIL (nothing to compare with must
    never look like a pass).
An app's files are data from another repository. The check runs none of the app's code: the only programs it runs are
this checkout's scripts and an engine file taken from this repository's own history. A copy with a symbolic link, or a
manifest or lock with a path that leaves its folder, is not built (NOTE or FAIL as above).
An app repository that cannot be fetched is a FAIL (no skip): the check needs network access to github.com.
Usage: python3 scripts/check_apps.py     Pass = last line "APPS apps=N fail=0".
"""
import json, os, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENGINE = ROOT / 'engine/rade_build.py'
SCHEMA = 'schemas/rade-manifest.schema.json'


def run(cmd, cwd=None):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=300)
    except subprocess.TimeoutExpired:
        return 124, 'timed out after 300 seconds'
    return r.returncode, (r.stdout + r.stderr).strip()


def tail(text, n=6):
    return '\n'.join('    ' + l[:220] for l in text.splitlines()[-n:])


def leaves(p):
    """True when a relative path from a manifest or a lock is not a plain path inside its folder."""
    return (not isinstance(p, str)) or p == '' or Path(p).is_absolute() or '..' in Path(p).parts or '\\' in p or ':' in p


def unsafe_paths(manifest):
    """Every path the engine reads or writes for this manifest that is not a plain path inside the app folder:
    bundle out, files[].src, fetch[].src, steps[].default.paths and application.knownDirs (engine/rade_build.py)."""
    paths = []
    for d in manifest['application'].get('knownDirs', []):
        paths += list(d) if isinstance(d, list) and len(d) == 2 else [None]   # the folder and its file pattern (the engine globs it)
    for b in manifest['bundles']:
        paths.append(b['out'])
        paths += [f['src'] for f in b.get('files', [])] + [f['src'] for f in b.get('fetch', []) if 'src' in f]
        for s in b.get('steps', []):
            if isinstance(s.get('default'), dict):
                paths += list(s['default'].get('paths', []))
    return [str(p) for p in paths if leaves(p)]


def links(folder):
    """Symbolic links in the copy (outside .git): a link could lead a plain path out of the folder."""
    out = []
    for base, dirs, files in os.walk(folder):
        if '.git' in dirs:
            dirs.remove('.git')
        out += [os.path.relpath(os.path.join(base, n), folder) for n in dirs + files if os.path.islink(os.path.join(base, n))]
    return out


def read_lock(app_dir, manifest_rel):
    """The app's lock as (commit, engine, files), or None when it has no lock file. LookupError: a lock that cannot be used."""
    lock_file = app_dir / Path(manifest_rel).parent / 'rade.lock.json'
    if not lock_file.is_file():
        return None
    try:
        lock = json.loads(lock_file.read_text())
        commit, engine, files = lock['commit'], lock['engine'], list(lock['files'])
    except (ValueError, KeyError, TypeError, OSError) as e:
        raise LookupError('the lock cannot be read (%s)' % type(e).__name__)
    if not (isinstance(commit, str) and len(commit) == 40 and all(c in '0123456789abcdef' for c in commit)):
        raise LookupError('the lock names no commit id')
    if engine != 'engine/rade_build.py' or engine not in files or any(leaves(f) for f in files):
        raise LookupError('the lock has a bad file path, or its engine is not engine/rade_build.py among its files')
    return commit, engine, files


def show(commit, rel):
    """One file of this repository at a commit (bytes). LookupError when the commit or the file is not there."""
    if run(['git', 'cat-file', '-e', commit + '^{commit}'], ROOT)[0] != 0:
        run(['git', 'fetch', '-q', 'origin', commit], ROOT)
    r = subprocess.run(['git', 'show', commit + ':' + rel], cwd=ROOT, capture_output=True, timeout=60)
    if r.returncode != 0:
        raise LookupError('commit %s (file %s) is not in this clone and could not be fetched' % (commit[:12], rel))
    return r.stdout


def locked_accepts(lock, app_dir, manifest_rel, tmp):
    """'' when the schema and the engine at the locked commit accept the app; else why not (the app is broken by itself)."""
    commit, engine, files = lock
    home = tmp / ('engine-' + commit[:12])
    for rel in files:
        dest = (home / rel)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(show(commit, rel))
    from jsonschema import Draft202012Validator
    try:
        errs = list(Draft202012Validator(json.loads(show(commit, SCHEMA))).iter_errors(json.loads((app_dir / manifest_rel).read_text())))
    except LookupError:
        errs = []   # an engine commit from before the schema file existed: the engine build below decides
    if errs:
        return 'its manifest does not follow the schema of its own locked engine (%s)' % errs[0].message[:120]
    code, out = run([sys.executable, '-B', str(home / engine), '--app-root', str(app_dir), '--manifest', manifest_rel])
    return '' if code == 0 else 'it does not build with its own locked engine:\n' + tail(out, 3)


def check(app, tmp):
    """Returns (status, lines): status is 'ok', 'fail' (this checkout breaks the app) or 'note' (the app is broken by itself)."""
    repo, manifest_rel = app['repo'], app['manifest']
    if leaves(manifest_rel):
        return 'fail', ['apps.json: the manifest path %r is not a plain path inside the repository' % manifest_rel]
    d = tmp / repo.replace('/', '__')
    code, out = run(['git', 'clone', '-q', '--depth', '1', 'https://github.com/%s.git' % repo, str(d)])
    if code != 0:
        return 'fail', ['cannot fetch the repository (this check needs network access to github.com):', tail(out, 3)]
    ln = links(d)
    if ln:
        return 'note', ['the repository has symbolic links, so it was not built: %s' % ', '.join(ln[:3])]
    try:
        manifest = json.loads((d / manifest_rel).read_text())
        bad = unsafe_paths(manifest)
        count = len(manifest['bundles'])
    except (OSError, ValueError, KeyError, TypeError, AttributeError, IndexError) as e:
        return 'note', ['the manifest %s on its main branch cannot be read as a RADE manifest (%s)' % (manifest_rel, type(e).__name__)]
    if bad:
        return 'note', ['the manifest has paths that leave the app folder, so it was not built: %s' % ', '.join(bad[:3])]
    if not count:
        return 'note', ['the manifest has no bundle, so nothing was built']
    base = tmp / (d.name + '__locked')
    shutil.copytree(d, base)   # the copy for the locked engine, made before this engine writes its bundles
    problems = []
    code, out = run([sys.executable, str(ROOT / 'scripts/check_manifest.py'), str(d / manifest_rel)])
    if code != 0:
        problems.append('scripts/check_manifest.py:\n' + tail(out))
    code, out = run([sys.executable, '-B', str(ENGINE), '--app-root', str(d), '--manifest', manifest_rel])
    if code != 0:
        problems.append('engine/rade_build.py:\n' + tail(out))
    elif out.count('BUILT ') != count:
        problems.append('engine/rade_build.py: built %d of %d bundles' % (out.count('BUILT '), count))
    if not problems:
        return 'ok', ['%d bundle(s) built with this engine' % count]
    try:
        lock = read_lock(base, manifest_rel)
        if lock is None:
            return 'note', ['this checkout does not build the app, and the app has no lock file, so there is nothing to compare with:'] + problems
        why = locked_accepts(lock, base, manifest_rel, tmp)
    except LookupError as e:
        return 'fail', ['this checkout does not build the app, and the app\'s locked engine cannot be used to compare (%s):' % e] + problems
    if why:
        return 'note', ['the app is broken by itself: ' + why]
    return 'fail', ['the app builds with its locked engine but NOT with this checkout. This change breaks the app:'] + problems


def main():
    apps = json.loads((ROOT / 'apps.json').read_text())['apps']
    fails = 0
    with tempfile.TemporaryDirectory() as t:
        for app in apps:
            try:
                status, lines = check(app, Path(t))
            except Exception as e:   # a fault in this check is never a pass
                status, lines = 'fail', ['the check itself stopped (%s: %s)' % (type(e).__name__, str(e)[:200])]
            print('%s %s (%s)' % ({'ok': 'PASS', 'fail': 'FAIL', 'note': 'NOTE'}[status], app.get('repo'), app.get('manifest')))
            for l in lines:
                print('  ' + l if not l.startswith('    ') else l)
            fails += status == 'fail'
    print('APPS apps=%d fail=%d' % (len(apps), fails))
    sys.exit(1 if fails or not apps else 0)


if __name__ == '__main__':
    main()
