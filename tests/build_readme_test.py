#!/usr/bin/env python3
"""Offline rules of scripts/build_readme.py (the README apps part): the page's steps are read, a script that does not
match its hash is refused, the facts are counted as the page counts them, and a missing mark is found.
Usage: python3 tests/build_readme_test.py   Pass = last line "README rules ok".
Run target: Python 3.
Network: none.
Writes: none.
Credentials: none.
Run by scripts/check.local.sh.
"""
import hashlib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'scripts'))
import build_readme as b

# 1. The steps of the real page: 3 items, entities written as plain characters, no HTML left.
steps = b.page_steps((b.ROOT / 'index.html').read_text(encoding='utf-8'))
assert len(steps) == 3 and steps[0].startswith('1. ') and 'File > New' in steps[1], steps
assert not any('<' in s or '&gt;' in s for s in steps), steps
try:
    b.page_steps('no list here')
    raise AssertionError('a page with no steps() list must fail')
except RuntimeError:
    pass

# 2. A script with a good hash line and stored hash: facts as the page counts them (UTF-8 bytes; lines = parts between LF).
body = 'Write-Host "a"\nWrite-Host "é"\n'
h = hashlib.sha256(body.encode('utf-8')).hexdigest()
text = '# @@BUNDLE-HASH %s @@\n%s' % (h, body)
size, lines, code = b.script_facts(text, {'sha256': h})
assert size == len(text.encode('utf-8')) and lines == 4 and code == h[:12] + '...' + h[-4:], (size, lines, code)

# 2b. A byte-order mark is removed first, as the page's fetch().text() does: same facts as without it.
assert b.script_facts('\ufeff' + text, {'sha256': h}) == (size, lines, code)

# 2c. Text from a manifest cannot add Markdown or HTML: markup characters are escaped.
assert b.md('a|b <i>[x](y) `c`') == 'a\\|b \\<i\\>\\[x\\](y) \\`c\\`', b.md('a|b <i>[x](y) `c`')
assert b.md('Round R40 r1: window r13, fake data.') == 'Round R40 r1: window r13, fake data.'
for bad in ['- fake', '1. x', '2) y', '---', '    code', 'A\n---', '~~x~~', '+ z', '= h', '![i](u)']:
    out = b.md(bad)   # one line, and no character left that starts a list, rule, code block, strike or image
    assert '\n' not in out and not re.match(r'(\d+[.)]|[-+=~!*]|\s)', out), (bad, out)
assert b.md('a\n\n  b') == 'a b'
assert b.md('$x^2$') == '\\$x^2\\$'   # no math
for good in ['a/b.ps1', 'scripts/gov/paste/90161Z-R40-round-r1.ps1']:
    assert b.plain_path(good), good
for bad in ['a b.ps1', 'a`b.ps1', '../x.ps1', 'a/../b.ps1', '/abs.ps1', 'a.ps1\n', 'a)b.ps1', 'x.txt', '']:
    assert not b.plain_path(bad), bad

# 3. Refused: no hash line, a changed text, a stored hash that differs or cannot be read.
for t, stored in [(body, {'sha256': h}), (text + 'x', {'sha256': h}), (text, {'sha256': '0' * 64}), (text, {})]:
    try:
        b.script_facts(t, stored)
        raise AssertionError('must refuse: %r' % stored)
    except RuntimeError:
        pass

# 4. Splice: the part goes between the marks; a missing mark gives None.
doc = 'top\n%s\nold\n%s\nend\n' % (b.MARK_A, b.MARK_B)
assert b.spliced(doc, 'new') == 'top\n%s\nnew\n%s\nend\n' % (b.MARK_A, b.MARK_B)
assert b.spliced('top\nend\n', 'new') is None and b.spliced('%s\n%s' % (b.MARK_B, b.MARK_A), 'x') is None

# 5. Fetch reads https only (fleet v2): a file:, http: or ftp: address is refused before any request.
for u in ['file:///etc/hostname', 'http://example.invalid/x', 'ftp://example.invalid/x', 'HTTPS-no-colon']:
    try:
        b.fetch(u)
        raise AssertionError('must refuse: %s' % u)
    except RuntimeError as e:
        assert 'only https' in str(e), e

print('README rules ok')
