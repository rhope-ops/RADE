#!/usr/bin/env python3
"""README top part: the RADE page's Ready card for each application, for a computer that cannot open github.io.

The Administrator, 2026-11-21: "a script that rebuilds the README top from apps.json and each app's list of scripts,
with a check that fails when the README is out of date". The text between the marks of MARK_A and MARK_B in README.md
is written from:
  - apps.json: the applications and the Teams channel name (`help`);
  - each application's RADE manifest on its main branch: the last bundle (the one the RADE page offers), its first
    catalog entry (summary, mode, version) and the application name;
  - the script itself and its stored hash (<script>.sha256.json): size, lines and the short hash, as the page shows them;
  - index.html: the paste steps (the page's STEPS list), so the steps have one home.
A script whose text does not match its own hash line or its stored hash is not written to the README: FAIL.

Usage: python3 scripts/build_readme.py [--write]   Pass = last line "README PASS apps=N" (fail: "README FAIL apps=N").
--write writes README.md; without it the check fails when README.md is not the current text.
scripts/check.local.sh runs the check in the full lane only (it needs github.com), as the app canary does.
Run target: Python 3.
Network: GET of each application's manifest, script and stored hash on raw.githubusercontent.com (read-only).
Writes: README.md (--write only).
Credentials: none.
"""
import hashlib
import html
import json
import pathlib
import re
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
README = ROOT / 'README.md'
APPS = ROOT / 'apps.json'
PAGE = ROOT / 'index.html'
MARK_A = '<!-- >>> apps: generated from apps.json by scripts/build_readme.py --write (do not edit) -->'
MARK_B = '<!-- <<< apps -->'
HASH_LINE = re.compile(r'^\s*# @@BUNDLE-HASH ([0-9a-f]{64}) @@\n')   # the same pattern as index.html scriptCheck()


def fetch(url):
    """Return the text at an https URL (UTF-8), or raise an error that names the URL."""
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={'Cache-Control': 'no-cache'}), timeout=60) as r:
            return r.read().decode('utf-8')
    except Exception as e:   # one message for every network or code error
        raise RuntimeError('%s did not load: %s' % (url, e)) from e


def short(h):
    """Return the short form of a SHA-256: the first 12 and the last 4 hex characters (as the page and the window)."""
    return h[:12] + '...' + h[-4:]


def page_steps(page):
    """Return the paste steps of the RADE page as Markdown list lines.

    Args:
        page: the text of index.html.

    Returns:
        One "1. ..." line for each <li> of the page's STEPS list, with the HTML entities written as plain characters.
    """
    m = re.search(r"var STEPS='(.*?)';", page, re.S)
    if not m:
        raise RuntimeError('index.html has no STEPS list')
    items = re.findall(r'<li>(.*?)</li>', m.group(1).replace("'+\n  '", '').replace("'+'", ''), re.S)
    if not items:
        raise RuntimeError('the STEPS list of index.html has no <li> items')
    return ['%d. %s' % (i + 1, html.unescape(t)) for i, t in enumerate(items)]


def script_facts(text, stored):
    """Check a script against its hash line and its stored hash, and return its facts.

    Args:
        text: the script text as fetched.
        stored: the parsed <script>.sha256.json.

    Returns:
        (bytes, lines, short hash), counted as the RADE page counts them (UTF-8 bytes; lines = parts between LF).
    """
    t = text.replace('\r\n', '\n')
    m = HASH_LINE.match(t)
    if not m:
        raise RuntimeError('the script has no hash line')
    got = hashlib.sha256(t[m.end():].encode('utf-8')).hexdigest()
    want = str(stored.get('sha256', ''))
    if got != m.group(1) or got != want:
        raise RuntimeError('the script does not match its hash: text %s, own line %s, stored %s' %
                           (short(got), short(m.group(1)), short(want) if len(want) == 64 else 'not readable'))
    return len(text.encode('utf-8')), len(text.split('\n')), short(got)


def app_section(app, steps, help_name):
    """Return the README Markdown of one application: the Ready card of the RADE page.

    Args:
        app: one entry of apps.json (repo, manifest, optional base).
        steps: the paste steps (page_steps()).
        help_name: the Teams channel name from apps.json.

    Returns:
        The section text, from its "## <name>" heading to the help line.
    """
    repo = app['repo']
    base = app.get('base') or 'https://raw.githubusercontent.com/%s/main/' % repo
    m = json.loads(fetch(base + app['manifest']))
    bundles = m.get('bundles') or []
    if not bundles or not bundles[-1].get('out'):
        raise RuntimeError('%s lists no script' % repo)
    b = bundles[-1]
    cat = (b.get('apps') or [{}])[0]
    name = (m.get('application') or {}).get('name') or repo
    mode, ver = cat.get('mode') or b.get('mode'), cat.get('version') or b.get('version')
    # The same kind line as index.html open(): Version / Install / Drift check / Test round.
    kind = ('Version ' + ver if ver else 'Install') if mode == 'deploy' else 'Drift check' if mode == 'drift' else \
        ('Test round ' + str(b.get('round') or '')).strip()
    raw = base + b['out']
    blob = 'https://github.com/%s/blob/main/%s' % (repo, b['out'])
    size, lines, code = script_facts(fetch(raw), json.loads(fetch(raw + '.sha256.json')))
    summary = cat.get('summary') or b.get('summary') or ''
    out = ['## ' + name, '', '**%s**' % kind, '', '### Copy the script for %s.' % name, '']
    if summary:
        out += [summary, '']
    out += ['`%s`<br>' % b['out'].split('/')[-1], '{:,} bytes, {:,} lines<br>'.format(size, lines),
            'Script check: `%s`, the stored hash ([.sha256.json](%s.sha256.json)). '
            'The RADE window shows the same value in its title bar.' % (code, blob), '',
            '| Link | What to do |', '| --- | --- |',
            '| **[Copy script](%s)** | Select "Copy raw file" (the copy button at the top right of the code). '
            'Then do the steps below. |' % blob,
            '| **[Open as .txt](%s)** | The script as plain text, to read before you paste. Ctrl+S saves it as a .txt file; '
            'Ctrl+A, then Ctrl+C copies it. |' % raw,
            '| **[Tasks for this application](https://github.com/%s)** | The %s repository: its tasks and round scripts. |'
            % (repo, name), '', 'If one link is blocked on your network, try the other.', ''] + steps + ['']
    if help_name:
        out.append('For help, ask in the Teams channel **%s**.' % help_name)
    return '\n'.join(out)


def generated():
    """Return the whole generated part (without the marks): one section for each application in apps.json."""
    c = json.loads(APPS.read_text(encoding='utf-8'))
    steps = page_steps(PAGE.read_text(encoding='utf-8'))
    return '\n\n'.join(app_section(a, steps, c.get('help', '')) for a in c['apps'])


def spliced(text, part):
    """Return the README text with the generated part replaced, or None when a mark is missing."""
    i, j = text.find(MARK_A), text.find(MARK_B)
    if i < 0 or j < i:
        return None
    return text[:i + len(MARK_A)] + '\n' + part + '\n' + text[j:]


def main(write):
    """Build the generated part, then check (or write) README.md. Exits 1 on a failure.

    Args:
        write: True to write README.md (--write), False to check it.
    """
    n = len(json.loads(APPS.read_text(encoding='utf-8'))['apps'])
    try:
        part = generated()
    except Exception as e:   # a fetch, a manifest or a hash problem: never written, never a pass
        print('README FAIL: ' + str(e))
        print('README FAIL apps=%d' % n)
        sys.exit(1)
    old = README.read_text(encoding='utf-8')
    new = spliced(old, part)
    if new is None:
        print('README FAIL: README.md: the marks of the generated part are missing')
    elif write and new != old:
        README.write_text(new, encoding='utf-8')
        print('README wrote README.md')
    elif new != old:
        print('README FAIL: README.md: out of date; run: python3 scripts/build_readme.py --write')
    ok = new is not None and (write or new == old)
    print('README %s apps=%d' % ('PASS' if ok else 'FAIL', n))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main(sys.argv[1:] == ['--write'])
