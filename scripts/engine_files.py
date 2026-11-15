#!/usr/bin/env python3
"""List every file under this repo that the engine reads in a build, each with its SHA-256 (the Administrator, 2026-11-15).

An app's lock must name these files (docs/engine.md "How an app gets the engine"). The list comes from the engine
itself: this script builds the sample app (schemas/examples/sample-manifest.json + tests/fixture-app, in a temporary
copy) under a Python audit hook and records each file the build opens under the repo. A search of the source cannot
give this list. Limit: it shows the files this sample build reads; an app with another manifest runs the same trace
on its own build.
Usage: python3 scripts/engine_files.py           lines "<sha256>  <path>" (shasum format, sorted by path)
       python3 scripts/engine_files.py --lock    JSON: repo, commit, engine and files, the fields an app lock needs
"""
import hashlib, json, os, runpy, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENGINE = 'engine/rade_build.py'
REPO = 'rhope-ops/RADE'


def trace():
    seen = set()
    root = os.path.realpath(ROOT) + os.sep

    def hook(event, args):
        if event == 'open' and isinstance(args[0], (str, bytes, os.PathLike)):
            p = os.path.realpath(os.fsdecode(args[0]))
            if p.startswith(root) and os.path.isfile(p) and '__pycache__' not in p:
                seen.add(p[len(root):].replace(os.sep, '/'))

    tmp = tempfile.mkdtemp(prefix='radefiles')
    old_argv, old_out = sys.argv, sys.stdout
    try:
        app = Path(tmp) / 'app'
        shutil.copytree(ROOT / 'tests/fixture-app', app)
        (app / 'scripts').mkdir(exist_ok=True)
        shutil.copy(ROOT / 'schemas/examples/sample-manifest.json', app / 'scripts/paste_bundles.json')
        sys.argv = [str(ROOT / ENGINE), '--app-root', str(app)]
        sys.stdout = open(os.devnull, 'w')
        sys.addaudithook(hook)
        try:
            runpy.run_path(str(ROOT / ENGINE), run_name='__main__')
        except SystemExit as e:
            if e.code not in (0, None):
                sys.stdout = old_out
                sys.exit('FAIL the sample build stopped with %r' % (e.code,))
    finally:
        sys.argv, sys.stdout = old_argv, old_out
        shutil.rmtree(tmp, ignore_errors=True)
    if ENGINE not in seen:
        sys.exit('FAIL the trace did not see %s' % ENGINE)
    return {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in sorted(seen)}


if __name__ == '__main__':
    files = trace()
    if '--lock' in sys.argv:
        commit = subprocess.run(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()
        print(json.dumps({'repo': REPO, 'commit': commit, 'engine': ENGINE, 'files': files}, indent=2))
    else:
        for p, h in files.items():
            print('%s  %s' % (h, p))
