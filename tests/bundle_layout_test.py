#!/usr/bin/env python3
"""Bundle layout test (docs/engine.md "Bundle layout"; the Administrator, 2026-11-17). Run by scripts/check.local.sh.

Builds the sample app (schemas/examples/sample-manifest.json + tests/fixture-app, in a temporary copy) after adding the
same marked block to two of its scripts, then checks:
  1. the Contents list names every part, file and engine part, and each line number points at that banner line;
  2. the block is kept once ($shared) and each script holds one "# @@SHARED" line in its place;
  3. the engine's own Expand-SharedBlock (engine/ps/03-files.ps1, run in pwsh) gives back each script's text exactly.
Output: one PASS or FAIL line per check, then "LAYOUT pass=N fail=M"; exit 1 on a failure. Needs Python 3 and pwsh 7.
"""
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BLOCK = ('# >>> demo-common: generated from scripts/gov/src/demo-common.ps1 by a test (do not edit)\n'
         '# Returns the sum of two numbers.\nfunction Get-DemoSum([int]$A, [int]$B) { return $A + $B }\n'
         '# <<< demo-common\n')
RESULTS = []


def check(ok, what):
    """Record and print one result line."""
    RESULTS.append(bool(ok))
    print(('PASS ' if ok else 'FAIL ') + what)


def make_app(tmp):
    """Copy the sample app into `tmp`, add BLOCK to two scripts, and return (app folder, {name: expected text})."""
    app = tmp / 'app'
    shutil.copytree(ROOT / 'tests/fixture-app', app)
    (app / 'scripts').mkdir(exist_ok=True)
    shutil.copy(ROOT / 'schemas/examples/sample-manifest.json', app / 'scripts/paste_bundles.json')
    want = {}
    for name in ('SAMPLE-T01-check-r1.ps1', 'SAMPLE-T03-verify-r1.ps1'):
        p = app / 'scripts/gov' / name
        text = p.read_bytes().decode('ascii').replace('\r\n', '\n')
        text = text + ('' if text.endswith('\n') else '\n') + BLOCK + '# end of test file\n'
        p.write_bytes(text.encode('ascii'))
        want[name] = text
    return app, want


def check_contents(text):
    """Check 1: each Contents row points at its banner line."""
    lines = text.split('\n')
    rows = re.findall(r'^#   line +(\d+)  +(.*)$', text, re.M)
    bad = [r for r in rows if not lines[int(r[0]) - 1].strip().endswith(r[1].strip()[:-3] if r[1].endswith('...') else r[1].strip())]
    check(rows and not bad, 'contents: %d rows, each line number points at its banner%s' % (len(rows), '' if not bad else ': ' + str(bad[:2])))
    kinds = [r[1].strip().split(':')[0].split(' ')[0] for r in rows]
    check({'Part', 'File', 'Engine'} <= set(kinds), 'contents: lists parts, files and engine parts')


def check_shared(text, want):
    """Checks 2 and 3: one $shared entry, one SHARED line per script, and pwsh puts the block back exactly."""
    check(text.count("$shared['demo-common-") == 1 and text.count('# @@SHARED demo-common-') == 2,
          'shared block: kept once, one SHARED line in each of the 2 scripts')
    part = text[text.index('# ==== Part 1 of'):text.index('# ==== Part 4 of')]   # settings, shared blocks, files: assignments only
    fn = (ROOT / 'engine/ps/03-files.ps1').read_text()
    fn = fn[fn.index('function Expand-SharedBlock'):]
    fn = fn[:fn.index('\n}\n') + 3]
    with tempfile.TemporaryDirectory() as d:
        script = Path(d) / 'expand.ps1'
        script.write_text(part + '\n' + fn + '\n$out = @{}\nforeach ($f in $files) { if ($f.Kind -eq "text") { $out[$f.Name] = Expand-SharedBlock $f.Data } }\n'
                          '$out | ConvertTo-Json -Compress\n')
        run = subprocess.run(['pwsh', '-NoProfile', '-File', str(script)], capture_output=True, text=True)
    got = json.loads(run.stdout or '{}')
    for name, text_want in want.items():
        g = (got.get(name) or '').replace('\r\n', '\n') + '\n'   # Write-BundleFile adds the last line break
        check(g == text_want, 'expand: %s comes back byte for byte' % name)


def main():
    """Build the test app and run the checks."""
    with tempfile.TemporaryDirectory() as d:
        app, want = make_app(Path(d))
        b = subprocess.run([sys.executable, str(ROOT / 'engine/rade_build.py'), '--app-root', str(app)], capture_output=True, text=True)
        check(b.returncode == 0, 'build of the test app' + ('' if b.returncode == 0 else ': ' + b.stdout[-300:] + b.stderr[-300:]))
        bundle = next((app / 'scripts/gov/paste').glob('*.ps1'), None)
        text = bundle.read_text(encoding='ascii') if bundle else ''
        check_contents(text)
        check_shared(text, want)
    print('LAYOUT pass=%d fail=%d' % (RESULTS.count(True), RESULTS.count(False)))
    return 0 if all(RESULTS) else 1


if __name__ == '__main__':
    sys.exit(main())
