#!/usr/bin/env python3
"""RADE engine, the bundle hash (docs/specs/bundle-hash.md; the Administrator, 2026-11-18). Used by engine/rade_build.py.

The first line of a built bundle is the hash line: it holds the SHA-256 of all the text after it (line ends as LF), so
the value is not inside the text it covers. The same value goes into a small stored file beside the bundle,
<bundle>.sha256.json, which the app commits with the bundle. Three places hash the same text and show the same short form
(first 12 and last 4 hex): the RADE page (index.html, which compares with the stored file), the bundle itself
(Get-ScriptCheck, engine/ps/05-installed.ps1) and this file. It catches a change on the way; it is no security control.
Inputs: a bundle text without its hash line (add_line), or a built bundle (the other functions). Outputs: text, or files.
How to run: it is not run by itself; `python3 engine/rade_build.py --app-root DIR` uses it for every bundle.
Network: none
Writes: the bundle file and its stored hash file, in the application's folder (write only)
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
