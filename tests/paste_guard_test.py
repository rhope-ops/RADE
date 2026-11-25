#!/usr/bin/env python3
"""Paste guard test (engine/rade_hash.py GUARD_START, GUARD_END; tool retirement plan P4a, the Maintainer, 2026-11-23).
Run by scripts/check.local.sh when an engine file changed.

Builds the sample app (schemas/examples/sample-manifest.json + tests/fixture-app, in a temporary copy) and cuts the
bundle after line N, as a paste that stops short does. Checks:
  1. the guard is in place: the start block right after the header comment, the end block as the last lines;
  2. each cut at 10, 25, 50, 75, 90 and 99 % of the lines, and at 200 more evenly spread lines, is a parse error,
     except a cut before the guard's script block opens or after it closes (pwsh parser, one process);
  3. such a parse-clean cut never holds a line of the body: it ends before "$script:PasteBody = {" or after its "}";
  4. run in pwsh, with a marker line as the body's first statement: a cut at 50 % ends with an error and runs nothing; a cut
     right before the last line (". $script:PasteBody") runs nothing and prints nothing; the whole copy runs the body
     (on this computer the body stops at the NIPR check, which prints its one message)..
The rounds of tests/engine_test.sh run the whole guarded bundle.
Output: one PASS or FAIL line per check, then "GUARD pass=N fail=M"; exit 1 on a failure. Needs Python 3 and pwsh 7.
Network: none
Writes: a temporary folder only (removed at the end)
Credentials: none
"""
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'engine'))
import rade_hash  # noqa: E402
RESULTS = []
# One pwsh process parses every cut: it reads the bundle and a list of line counts, and prints "N ok" or "N error".
PARSE = r'''param($f, $list)
$all = [System.IO.File]::ReadAllText($f) -split "`n"
foreach ($n in (Get-Content -LiteralPath $list)) {
  $t = $null; $e = $null
  $null = [System.Management.Automation.Language.Parser]::ParseInput((($all[0..([int]$n - 1)]) -join "`n"), [ref]$t, [ref]$e)
  Write-Output ($n + ' ' + $(if ($e.Count) { 'error' } else { 'ok' }))
}
'''


def check(name, good, detail=''):
    """Record one result as a PASS or FAIL line (with `detail` after a FAIL)."""
    RESULTS.append(good)
    print(('PASS ' if good else 'FAIL ') + name + ('' if good or not detail else ': ' + detail))


def build(tmp):
    """Build the sample bundle in a copy of the fixture app.

    Args:
        tmp: an empty folder; the copy of the app goes in tmp/app.

    Returns:
        The lines of the built bundle (split at LF). Exits with a FAIL line when the build fails.
    """
    app = tmp / 'app'
    shutil.copytree(ROOT / 'tests/fixture-app', app)
    (app / 'scripts').mkdir(exist_ok=True)
    shutil.copy(ROOT / 'schemas/examples/sample-manifest.json', app / 'scripts/paste_bundles.json')
    r = subprocess.run([sys.executable, str(ROOT / 'engine/rade_build.py'), '--app-root', str(app)], capture_output=True, text=True)
    if r.returncode:
        sys.exit('FAIL build of the sample bundle\n' + r.stdout + r.stderr)
    out = json.loads((ROOT / 'schemas/examples/sample-manifest.json').read_text())['bundles'][0]['out']
    return (app / out).read_text(encoding='ascii').split('\n')


def run_cut(tmp, lines, n):
    """Write the first `n` lines as a .ps1 file, run it in pwsh; return (exit code, output)."""
    f = tmp / ('cut-%d.ps1' % n)
    f.write_text('\n'.join(lines[:n]) + '\n', encoding='ascii')
    r = subprocess.run(['pwsh', '-NoProfile', '-NonInteractive', '-File', str(f)], capture_output=True, text=True, stdin=subprocess.DEVNULL, timeout=120)
    return r.returncode, r.stdout + r.stderr


def main():
    """Run the checks; exit 1 when one fails."""
    tmp = Path(tempfile.mkdtemp(prefix='rade-guard-'))
    try:
        lines = build(tmp)
        if lines and lines[-1] == '':
            lines = lines[:-1]
        start = rade_hash.GUARD_START.rstrip('\n').split('\n')
        end = rade_hash.GUARD_END.rstrip('\n').split('\n')
        at = lines.index(start[0]) if start[0] in lines else -1
        check('guard start right after the header comment', at > 0 and lines[at - 1] == '#>' and lines[at:at + len(start)] == start)
        check('guard end as the last lines', lines[-len(end):] == end)
        opens, closes = at + start.index('$script:PasteBody = {') + 1, len(lines) - len(end) + 1   # line numbers (1-based) of "{" and of "}"
        total = len(lines)
        cuts = sorted({max(1, total * p // 100) for p in (10, 25, 50, 75, 90, 99)} | {max(1, total * k // 201) for k in range(1, 201)}
                      | set(range(1, opens + 1)) | set(range(closes, total)))
        lst = tmp / 'cuts.txt'
        lst.write_text('\n'.join(map(str, cuts)) + '\n')
        ps = tmp / 'parse.ps1'
        ps.write_text(PARSE)
        whole = tmp / 'whole.ps1'
        whole.write_text('\n'.join(lines) + '\n', encoding='ascii')
        r = subprocess.run(['pwsh', '-NoProfile', '-NonInteractive', '-File', str(ps), str(whole), str(lst)], capture_output=True, text=True, timeout=600)
        got = dict(l.split() for l in r.stdout.split('\n') if l.strip())
        clean = sorted(int(n) for n, v in got.items() if v == 'ok')
        inside = [n for n in clean if opens <= n < closes]
        check('every cut was parsed (%d cuts)' % len(cuts), len(got) == len(cuts), r.stderr[-300:])
        check('no parse-clean cut holds a line of the body (%d parse-clean, all before line %d or from line %d)' % (len(clean), opens, closes), not inside, str(inside[:5]))
        # The runs: a test copy with one marker line as the body's first statement (the line numbers above are of the real bundle).
        marked = lines[:opens] + ["Write-Host 'BODY RAN'"] + lines[opens:]
        code, out = run_cut(tmp, marked, len(marked) // 2)
        check('a cut at 50 % ends with an error and runs nothing', code != 0 and 'BODY RAN' not in out, out[-300:])
        code, out = run_cut(tmp, marked, len(marked) - 1)
        check('a cut before the last line runs nothing and prints nothing', code == 0 and not out.strip(), out[-300:])
        code, out = run_cut(tmp, marked, len(marked))
        check('the whole copy runs the body (here: the NIPR stop, as on a computer that is not on NIPR)',
              out.split('\n')[0] == 'BODY RAN' and 'This application cannot be installed in your environment.' in out, out[-300:])
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    bad = RESULTS.count(False)
    print('GUARD pass=%d fail=%d' % (len(RESULTS) - bad, bad))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
