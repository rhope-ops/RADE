#!/usr/bin/env python3
"""RADE engine, the bundle hash (docs/specs/bundle-hash.md; the Administrator, 2026-11-18). Used by engine/rade_build.py.

The first line of a built bundle is the hash line: it holds the SHA-256 of all the text after it (line ends as LF), so
the value is not inside the text it covers. The same value goes into a small stored file beside the bundle,
<bundle>.sha256.json, which the app commits with the bundle. Three places hash the same text and show the same short form
(first 12 and last 4 hex): the RADE page (index.html, which compares with the stored file), the bundle itself
(Get-ScriptCheck, engine/ps/05-installed.ps1) and this file. It catches a change on the way; it is no security control.
Inputs: a bundle text without its hash line (add_line), or a built bundle (the other functions). Outputs: text, or files.
How to run: `python3 engine/rade_build.py --app-root DIR` uses it for every bundle. `python3 engine/rade_hash.py --content
FILE...` prints the content hash of each file (content_hash: UI standard v1 brief item 9, the Administrator, 2026-11-20):
the same value for two revisions of a test that differ only in their revision tokens and their header comment lines,
so an app can tell that a test did not change and retire its old revision.
Network: none
Writes: the bundle file and its stored hash file, in the application's folder (write only; --content writes nothing)
Credentials: none
"""
import hashlib
import json
import re
from pathlib import Path

HASH_LINE = '# @@BUNDLE-HASH %s @@\n'


def add_line(rest):
    """Return the whole bundle: the hash line of `rest` (the bundle text without it, ASCII with LF line ends), then `rest`."""
    return HASH_LINE % hashlib.sha256(rest.encode('ascii')).hexdigest() + rest


def record(out, text, release):
    """Return the text of the stored hash file of one built bundle.

    Args:
        out: the bundle's path (only its name is used).
        text: the whole bundle, hash line first.
        release: the engine release number (ENGINE_RELEASE of the build).

    Returns:
        JSON text: file, sha256 (the value on the hash line), short (the form a person compares: first 12 and last 4
        hex), buildId and engineRelease.
    """
    sha = re.match(r'# @@BUNDLE-HASH ([0-9a-f]{64}) @@\n', text).group(1)
    build_id = re.search(r"(?m)^\$buildId = '([0-9a-f]{8})'$", text).group(1)
    rec = {'file': Path(out).name, 'sha256': sha, 'short': sha[:12] + '...' + sha[-4:], 'buildId': build_id, 'engineRelease': release}
    return json.dumps(rec, indent=2) + '\n'


def stored(out):
    """The path of the stored hash file of the bundle at `out`: the same name with .sha256.json after it."""
    return out.with_name(out.name + '.sha256.json')


def stale(out, text, release, label):
    """Tell whether a built bundle on disk is out of date, and print a STALE line when it is.

    Args:
        out: the bundle's path.
        text: the whole bundle this build gives.
        release: the engine release number.
        label: the bundle's path as the manifest gives it, for the STALE line.

    Returns:
        1 when the bundle file or its stored hash file is missing or differs (bytes), else 0.
    """
    rec = stored(out)
    old = (not out.exists() or out.read_bytes() != text.encode('ascii')
           or not rec.exists() or rec.read_bytes() != record(out, text, release).encode('ascii'))
    if old:
        print('STALE ' + label)
    return int(old)


def write(out, text, release):
    """Write the bundle and its stored hash file (as bytes: the same files on every platform). Returns the HASH line to print."""
    rec = record(out, text, release)
    out.write_bytes(text.encode('ascii'))
    stored(out).write_bytes(rec.encode('ascii'))
    sha = json.loads(rec)
    return 'HASH %s %s (%s)' % (out.name, sha['sha256'], sha['short'])


# A revision token: r or R and a number, as a word (r8, R37, -r1.): what changes between two revisions of a test.
REVISION = re.compile(r'(?<![A-Za-z0-9])[rR][0-9]+(?![0-9A-Za-z])')


def content_hash(text):
    """Return the content hash of a script text: the SHA-256 of its body, with revision tokens and header lines left out.

    Args:
        text: the script text (any line ends; a byte order mark is left out).

    Returns:
        64 hex. The header is every line before the first line of code: blank lines, '#' comment lines and a <# ... #>
        block at the start. In the body each revision token (REVISION) reads 'r#' and line ends are LF, so only a change
        of the code itself changes the value.
    """
    lines = text.lstrip('\ufeff').replace('\r\n', '\n').replace('\r', '\n').split('\n')
    i, block = 0, False
    while i < len(lines):
        t = lines[i].strip()
        if block:
            block = '#>' not in t
        elif t.startswith('<#'):
            block = '#>' not in t[2:]
        elif t and not t.startswith('#'):
            break
        i += 1
    body = REVISION.sub('r#', '\n'.join(lines[i:]))
    return hashlib.sha256(body.encode('utf-8')).hexdigest()


if __name__ == '__main__':
    import sys
    if len(sys.argv) < 3 or sys.argv[1] != '--content':
        sys.exit('usage: python3 engine/rade_hash.py --content FILE...')
    for f in sys.argv[2:]:
        print('CONTENT %s %s' % (content_hash(Path(f).read_text(encoding='utf-8')), f))
