#!/usr/bin/env python3
"""App canary: does this engine still build every real application? (the Administrator, 2026-11-15)

RADE's own tests use a sample app, so a change to the contract between RADE and the apps (manifest fields, check ids,
build rules) could pass here and break an app later, at its lock change. This check finds that before a release.

For each application in apps.json it makes a fresh, shallow copy of the app repository's main branch in a temporary
folder (read-only: nothing is pushed, the app repository is never changed, and no RADE checkout of the app is used), then:
  1. checks the app's manifest with scripts/check_manifest.py (the schema in this checkout);
  2. builds every bundle with the engine in this checkout.
Before a build it puts in the engine's font files that an app's own build copies (stage_fonts: a missing bundle file
<folder>/fonts/build/<prefix>-<name> gets the engine's engine/fonts/<name>; the Administrator, 2026-11-21: the check
copies them itself and runs no app code). The locked build gets the files of the locked commit.
A bundle that builds is also read for the words of the "No reconnaissance" rule (scripts/no_recon.py): NOTE lines only.
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
import json, os, re, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'scripts'))
import no_recon   # the word search of the "No reconnaissance" rule (scripts/no_recon.py)
ENGINE = ROOT / 'engine/rade_build.py'
SCHEMA = 'schemas/rade-manifest.schema.json'
FONT_RE = re.compile(r'(?:[A-Za-z0-9_-]+/)*fonts/build/[A-Za-z0-9]+-([A-Za-z0-9][A-Za-z0-9.-]*)')   # a bundle file an app's build copies from engine/fonts


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


def locked_font(commit, name):
    """The bytes of engine/fonts/<name> at a commit of this repository, or None: a bad name, no such file, or not a file."""
    if not font_name_ok(name):
        return None
    rel = 'engine/fonts/' + name
    try:
        data = show(commit, rel)
    except LookupError:
        return None
    return data if git_type(commit, rel) == 'blob' else None


def git_type(commit, rel):
    """The git object type of a path at a commit ('blob' for a file), from stdout only (a warning on stderr changes
    nothing); '' when it cannot be read."""
    try:
        r = subprocess.run(['git', 'cat-file', '-t', commit + ':' + rel], cwd=ROOT, capture_output=True, text=True, timeout=60)
    except subprocess.TimeoutExpired:
        return ''
    return r.stdout.strip() if r.returncode == 0 else ''


def locked_accepts(lock, app_dir, manifest_rel, tmp):
    """'' when the schema and the engine at the locked commit accept the app; else why not (the app is broken by itself)."""
    commit, engine, files = lock
    home = tmp / ('engine-' + commit[:12])
    for rel in files:
        dest = (home / rel)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(show(commit, rel))
    stage_fonts(app_dir, json.loads((app_dir / manifest_rel).read_text()), lambda name: locked_font(commit, name))
    from jsonschema import Draft202012Validator
    try:
        errs = list(Draft202012Validator(json.loads(show(commit, SCHEMA))).iter_errors(json.loads((app_dir / manifest_rel).read_text())))
    except LookupError:
        errs = []   # an engine commit from before the schema file existed: the engine build below decides
    if errs:
        return 'its manifest does not follow the schema of its own locked engine (%s)' % errs[0].message[:120]
    code, out = run([sys.executable, '-B', str(home / engine), '--app-root', str(app_dir), '--manifest', manifest_rel])
    return '' if code == 0 else 'it does not build with its own locked engine:\n' + tail(out, 3)


def stage_fonts(app_dir, manifest, read_font):
    """Puts in the engine font files that an app's own build copies before it builds (90-161.Z: copy_fonts in its
    scripts/build_paste_bundles.py); the check runs no app code, so it copies them itself (the Administrator, 2026-11-21).

    Args:
        app_dir: the app copy (Path).
        manifest: the app's manifest (dict).
        read_font: gives the bytes of engine/fonts/<name> of the engine used, or None when it has no such file.

    Returns:
        The bundle file paths copied. A path that leaves the folder, a file already there and a name the engine does not
        have are left alone (the build then names the missing file).
    """
    copied = []
    for b in manifest.get('bundles', []):
        for f in b.get('files', []):
            src = f.get('src') if isinstance(f, dict) else None
            m = FONT_RE.fullmatch(src) if isinstance(src, str) and not leaves(src) else None
            dst = app_dir / src if m else None
            if not m or dst.exists() or dst.is_symlink():
                continue
            data = read_font(m.group(1))
            if data is None:
                continue
            try:   # a file where a folder should be (a broken app), or a write that stops: left to the build, which names it
                dst.parent.mkdir(parents=True, exist_ok=True)
                part = dst.with_name(dst.name + '.part')
                part.write_bytes(data)
                os.replace(part, dst)   # whole or not there: never a cut font
            except OSError:
                try:
                    part.unlink()
                except (OSError, NameError):
                    pass
                continue
            copied.append(src)
    return copied


def font_name_ok(name):
    """True for a plain font file name (no folder, no '..'): the only names the check reads from engine/fonts."""
    return bool(re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]*', name)) and '..' not in name


def this_font(name):
    """The bytes of engine/fonts/<name> in this checkout, or None (also for a name with a folder in it)."""
    if not font_name_ok(name):
        return None
    p = ROOT / 'engine/fonts' / name
    return p.read_bytes() if p.is_file() else None


def recon_notes(app_dir, manifest):
    """Lines for the words of the "No reconnaissance" rule (AGENTS.md "Project rules") in the app's built bundles.
    A note for the app's own session and never a FAIL: the search also reads comments, and RADE cannot fix an app."""
    lines = []
    for b in manifest['bundles']:
        out = app_dir / b['out']
        text = out.read_text(encoding='utf-8', errors='replace') if out.is_file() else ''
        lines += ['no-reconnaissance word to review: %s:%d: %s: %s' % (b['out'], n, kind, word) for n, kind, word in no_recon.find(text)]
    return lines[:8] + (['... and %d more' % (len(lines) - 8)] if len(lines) > 8 else [])


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
    fonts = stage_fonts(d, manifest, this_font)
    code, out = run([sys.executable, str(ROOT / 'scripts/check_manifest.py'), str(d / manifest_rel)])
    if code != 0:
        problems.append('scripts/check_manifest.py:\n' + tail(out))
    code, out = run([sys.executable, '-B', str(ENGINE), '--app-root', str(d), '--manifest', manifest_rel])
    if code != 0:
        problems.append('engine/rade_build.py:\n' + tail(out))
    elif out.count('BUILT ') != count:
        problems.append('engine/rade_build.py: built %d of %d bundles' % (out.count('BUILT '), count))
    if not problems:
        # A text longer than its limit (docs/window-design.md "Text lengths") is a note for the app's own session, not a FAIL.
        long = sorted(set(l.replace('WARNING text length: ', 'text length: ') for l in out.splitlines() if l.startswith('WARNING text length: ')))
        staged = ['%d font file(s) put in from this engine before the build (the app\'s own build copies them)' % len(fonts)] if fonts else []
        return 'ok', ['%d bundle(s) built with this engine' % count] + staged + long + recon_notes(d, manifest)
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
