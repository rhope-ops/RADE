#!/usr/bin/env python3
"""RADE engine: the engine's PowerShell parts and the fixed lists of the build (moved out of engine/rade_build.py on
2026-11-23 to keep each file at 450 lines or fewer; fleet v2 DEC 6). engine/rade_build.py imports every name here.

It holds: the part lists (ENGINE_PARTS, WINDOW_PARTS) and engine_text, which joins engine/ps into the text every bundle
carries (ENGINE); the check ids; the plain-name patterns; word_list (the answers of a guide step); the bundle layout
patterns and shared_blocks; the window layout values of engine/window.json; the script extensions a collect name must
not match; and the part list of a bundle header.
Run target: Python 3 (the build).
Network: none.
Writes: none.
Credentials: none.
"""
import fnmatch, hashlib, json, re
from pathlib import Path

ENGINE_ROOT = Path(__file__).resolve().parent.parent
WINDOW_FILE = ENGINE_ROOT / 'engine/window.json'   # the window's layout values (the Administrator, 2026-11-18; docs/window-design.md)


# ---- The engine's PowerShell (the Administrator, 2026-11-17: docs/code-standard.md C10). It lives in engine/ps as
# files that a person, the PowerShell parser and scripts/code_standard.py can read one by one; this build joins them
# in run order into the text every bundle carries. Each part is a whole file that parses alone. The window parts are
# kept 4 spaces less indented than in the bundle and go where engine/ps/10-window.ps1 has its "# @@WINDOW@@" line.
ENGINE_DIR = ENGINE_ROOT / 'engine/ps'
ENGINE_PARTS = ['01-base.ps1', '02-config.ps1', '03-files.ps1', '04-steps.ps1', '05-installed.ps1', '06-round.ps1', '12-resume.ps1',
                '07-checks.ps1', '08-saved-checks.ps1', '13-maintenance.ps1', '14-restore.ps1', '15-restore-run.ps1', '09-start.ps1', '10-window.ps1', '11-text-mode.ps1']
WINDOW_PARTS = ['window/01-setup.ps1', 'window/02-fixed-parts.ps1', 'window/03-card.ps1', 'window/04-record-parts.ps1',
                'window/05-alignment.ps1', 'window/06-open.ps1', 'window/07-run.ps1', 'window/08-hand-step.ps1',
                'window/09-record.ps1', 'window/11-tools.ps1', 'window/10-keys.ps1']   # 11-tools before 10-keys: the keys part shows the form
WINDOW_SLOT = '    # @@WINDOW@@\n'


def indent(text, pad):
    """Return `text` with `pad` put before each line that is not empty."""
    return ''.join((pad + x) if x.strip('\n') else x for x in text.splitlines(keepends=True))


def file_sha(rel):
    """Return the first 12 hex of the SHA-256 of one engine file (`rel` under the RADE root): the hash an app's lock
    holds for it, so a reader (and the app's own test) can match each part of a bundle to its locked file."""
    return hashlib.sha256((ENGINE_ROOT / rel).read_bytes()).hexdigest()[:12]


def engine_text():
    """Join the engine's PowerShell parts. The build stops when engine/ps and the part lists differ, or when the
    window slot is not there exactly once (a part or a slot would else be left out without a word).

    Returns:
        The parts of ENGINE_PARTS in order, with the window parts (indented 4 spaces) in the slot of 10-window.ps1.
        The text starts with a newline, as the bundle layout expects.
    """
    read = lambda rel: (ENGINE_DIR / rel).read_text(encoding='ascii')
    on_disk = sorted(p.relative_to(ENGINE_DIR).as_posix() for p in ENGINE_DIR.rglob('*.ps1'))
    assert on_disk == sorted(ENGINE_PARTS + WINDOW_PARTS), 'engine/ps and the part lists differ: %s' % sorted(
        set(on_disk) ^ set(ENGINE_PARTS + WINDOW_PARTS))   # a part nobody listed would be left out without a word
    assert sum(read(p).count(WINDOW_SLOT) for p in ENGINE_PARTS) == 1, 'the window slot (# @@WINDOW@@) must be there once'
    banner = lambda rel: '# ==== Engine part: engine/ps/%s (sha256 %s)\n' % (rel, file_sha('engine/ps/' + rel))   # in the Contents
    window = ''.join(indent(banner(w) + read(w), '    ') for w in WINDOW_PARTS)
    text = ''.join(banner(p) + read(p).replace(WINDOW_SLOT, window) for p in ENGINE_PARTS)
    return '\n' + text


ENGINE = engine_text()

# Checks every application runs (the rest come from its steps' "needs"). Ids must exist in the engine's $checkDefs.
BASE_CHECKS = ['nipr', 'ps', 'lang', 'onedrive', 'disk', 'write', 'child', 'outlook', 'net-bookmark']
CHECK_IDS = re.findall(r"@\{ Id = '([a-z-]+)'", ENGINE)


START_RE = re.compile(r'[A-Za-z0-9][A-Za-z0-9 ._-]*(/[A-Za-z0-9][A-Za-z0-9 ._-]*)*\.ps1')   # schemas/rade-manifest.schema.json app.start says the same
WIN_RESERVED = {'CON', 'PRN', 'AUX', 'NUL'} | {'%s%d' % (p, k) for p in ('COM', 'LPT') for k in range(1, 10)}   # file names Windows refuses (a backup file)


def word_list(value, allowed):
    """Say whether `value` is a list of 1 or more different words that are all in `allowed` (spaces at the ends ignored)."""
    got = [w.strip() for w in value] if isinstance(value, list) and all(isinstance(w, str) for w in value) else []
    return bool(got) and len(set(got)) == len(got) and all(w in allowed for w in got)



# ---- Bundle layout (the Administrator, 2026-11-17: docs/code-standard.md C5, C6). A bundle is read by a person before it
# runs, so it starts with a list of its parts and their line numbers, and each part and each file has a banner line.
BANNER = re.compile(r'^\s*# (==== |---- File )')
# A block between "# >>> <name>: generated from ..." and "# <<< <name>" that two or more text files hold (a shared
# source copied into each script that must run alone) is kept once, in $shared, and each file holds one line in its
# place; the engine puts the block back when it writes the file (Write-BundleFile), so every file is the same as before.
SHARED_RE = re.compile(r'^# >>> ([\w-]+): generated from .*?\n# <<< \1\n', re.M | re.S)
SHARED_LINE = '# @@SHARED %s@@ (RADE writes the shared block "%s" here; its text is in the bundle part "Shared blocks")'


def shared_blocks(texts):
    """Find the marked blocks that two or more of the text files hold. Takes {source path: text}; returns
    {key: block text}, where key = the block name and the first 8 hex of its SHA-256 (two versions get two keys)."""
    seen = {}
    for text in texts.values():
        for m in SHARED_RE.finditer(text):
            key = '%s-%s' % (m.group(1), hashlib.sha256(m.group(0).encode()).hexdigest()[:8])
            seen.setdefault(key, [m.group(0), 0])[1] += 1
    return {k: v[0] for k, v in seen.items() if v[1] > 1}



def window_values():
    """Read engine/window.json and check it. The build stops when a value is missing or out of range.

    Returns:
        A dict of placeholder -> text: text column share (percent) and cap, minimum window size and frame height (pixels at 100 %), minimum step time (ms).
    """
    w = json.loads(WINDOW_FILE.read_text(encoding='utf-8'))
    share, cap = float(w['textColumn']['sharePercent']), int(w['textColumn']['maxPx'])
    min_w, min_h = int(w['minSize']['width']), int(w['minSize']['height'])
    assert 40 <= share <= 100, 'engine/window.json textColumn.sharePercent must be 40 to 100'
    assert 240 <= cap <= 4000, 'engine/window.json textColumn.maxPx must be 240 to 4000'
    assert 400 <= min_w <= 1920 and 300 <= min_h <= 1080, 'engine/window.json minSize must be 400 x 300 to 1920 x 1080'
    frame, step_ms = int(w['cardFrame']['minHeight']), int(w['minStepMs'])
    assert 120 <= frame <= 1080 and 0 <= step_ms <= 3000, 'engine/window.json cardFrame.minHeight must be 120 to 1080 and minStepMs 0 to 3000'
    return {'@@TEXT_SHARE@@': repr(share), '@@TEXT_MAX@@': str(cap), '@@MIN_W@@': str(min_w), '@@MIN_H@@': str(min_h),
            '@@FRAME_MIN@@': str(frame), '@@MIN_STEP_MS@@': str(step_ms)}


# No scripts in results (the PFM, 2026-11-20; R37: a collect pattern matched the .ps1 runner and the work e-mail gateway
# blocked the results e-mail). The one list of script extensions: the build refuses a collect name that can match one,
# and every bundle carries it ($scriptExts) so the collect step never copies such a file (engine/ps/04-steps.ps1).
SCRIPT_EXTS = ['.ps1', '.psm1', '.psd1', '.bat', '.cmd', '.vbs', '.js', '.wsf', '.hta', '.py', '.sh', '.exe', '.dll', '.msi',
               '.lnk', '.scr']


def ends_in(pat, x):
    """Return True when collect name pat can match a name that ends in x: only its text after the last * limits the end."""
    tail = pat.lower().rsplit('*', 1)[-1]
    if len(tail) >= len(x):
        return fnmatch.fnmatchcase(x, tail[-len(x):])
    return '*' in pat and fnmatch.fnmatchcase(x[len(x) - len(tail):], tail)


def collect_problems(b):
    """Return one line for each collect name of bundle b (names joined by ';' one by one) that can match a script file."""
    return ['collect %s\\%s: the name can match a script file (%s); name the result files by their own extension, for '
            'example *.pdf (scripts never go in results)' % (c['dir'], p, ' '.join(SCRIPT_EXTS))
            for c in b['collect'] for p in c['name'].split(';') if any(ends_in(p, x) for x in SCRIPT_EXTS)]


def part_lines():
    """Return the header lines that name each engine PowerShell part with its own SHA-256, 4 to a line, each entry
    ending in ";" (the form "<file>, sha256 <12 hex>;" that an app's test matches against its lock)."""
    rels = ['engine/ps/' + x for x in ENGINE_PARTS + WINDOW_PARTS]
    rows = [' '.join('%s, sha256 %s;' % (r, file_sha(r)) for r in rels[k:k + 4]) for k in range(0, len(rels), 4)]
    return '  Engine parts, in run order:\n' + ''.join('    %s\n' % r for r in rows)
