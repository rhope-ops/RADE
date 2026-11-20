#!/usr/bin/env python3
"""Unit test of the content hash (engine/rade_hash.py content_hash; UI standard v1 brief item 9, the Administrator, 2026-11-20).

Pass = last line "RADE-HASH pass=N fail=0": a one-character change of the body flips the hash; a change of the header
comment lines, of a revision token or of the line ends does not.
Run target: Python 3.
Network: none.
Writes: none.
Credentials: none.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / 'engine'))
import rade_hash  # noqa: E402

BASE = "# Sample test r1 (header)\n<#\n.SYNOPSIS\nSample\n#>\n$rev = 'r1'\nWrite-Host 'T05-sample-r1.ps1 ran'\n"
CASES = [
    ('a one-character body change flips the hash', BASE.replace("ran'", "run'"), False),
    ('a header comment change keeps the hash', BASE.replace('(header)', '(header, revised 20 Nov 26)'), True),
    ('a revision token change keeps the hash', BASE.replace('r1', 'r2'), True),
    ('CRLF line ends keep the hash', BASE.replace('\n', '\r\n'), True),
    ('a new body line flips the hash', BASE + "Write-Host 'more'\n", False),
    ('a number that is no revision token flips the hash', BASE.replace("'r1'\n", "'r1' # 1\n").replace("ran'", "ran 2'"), False),
]


def main():
    """Run each case and print one line for it, then the summary line. Exits 1 on a failure."""
    base, ok, bad = rade_hash.content_hash(BASE), 0, 0
    for name, text, same in CASES:
        good = (rade_hash.content_hash(text) == base) == same
        ok, bad = ok + good, bad + (not good)
        print(('PASS ' if good else 'FAIL ') + name)
    print('RADE-HASH pass=%d fail=%d' % (ok, bad))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
