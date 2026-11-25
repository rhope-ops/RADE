#!/usr/bin/env python3
"""Make the RADE fonts (engine/fonts) from the Sofia Sans release files: a Latin subset of each (UI standard v1).

The Administrator, 2026-11-20 (docs/ui-standard.md "Type"): Sofia Sans Condensed for titles, Sofia Sans for text, an open
font under the SIL Open Font License 1.1 (engine/fonts/OFL.txt; the licence names no Reserved Font Name, so a subset
keeps the family names). Source: github.com/lettersoup/Sofia-Sans at commit SOURCE_COMMIT, the static TTF files in
fonts/ttf (the Google Fonts repo has only the variable fonts, which GDI+ cannot weight). Each file is cut to the
characters in UNICODES and loses its OpenType layout tables (GDI, which draws Windows Forms text, does not use them):
about 43 KB in place of about 190 KB, so a bundle carries about 170 KB of base64, not 770 KB.

Usage: python3 scripts/build_fonts.py SOURCE_DIR   (SOURCE_DIR holds the files of SOURCES, downloaded by hand)
Needs: fontTools 4.55.3 from PyPI (pinned with its hash in requirements.txt: pip install --require-hashes -r requirements.txt), only to make the files again; no check needs it.
Run target: Python 3 on Linux or Windows.
Network: none (the source files are downloaded by hand from raw.githubusercontent.com, checked by SHA-256 here).
Writes: engine/fonts/*.ttf (then name each in engine/ui-tokens.json "faces" and run python3 engine/rade_tokens.py --write).
Credentials: none.
"""
import hashlib
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE_COMMIT = '185877d082cebb40facd65143326147431863688'
# source file (path in the source repo) -> (its SHA-256, the file it makes in engine/fonts)
SOURCES = {
    'fonts/ttf/Normal/SofiaSans-Regular.ttf': ('8b9b68e14433b29223bfa761c48fff29bef07e56b30cc94519f130a4d9604f25', 'SofiaSans-Regular.ttf'),
    'fonts/ttf/Normal/SofiaSans-SemiBold.ttf': ('cdf0f41907190aced199fd508c5b277e430e5cf42305d8608904bf9e5e22dc65', 'SofiaSans-SemiBold.ttf'),
    'fonts/ttf/Condensed/SofiaSansCondensed-SemiBold.ttf': ('8c7b151f8d891493e510acaec96d9df57b20f939600665a0a1910e92fa248999', 'SofiaSansCondensed-SemiBold.ttf'),
}
# Basic Latin, Latin-1 and Latin Extended-A, dashes, quotes, bullet and ellipsis, per mille and angle quotes, arrows,
# minus, euro, trade mark.
UNICODES = 'U+0020-007E,U+00A0-017F,U+2010-2027,U+2030-203A,U+2190-2193,U+2212,U+20AC,U+2122'


def main(src):
    """Check each source file's SHA-256, then write its subset into engine/fonts.

    Args:
        src: the folder that holds the source files (their base names).
    """
    from fontTools import subset   # only here: no check imports this script
    (ROOT / 'engine/fonts').mkdir(exist_ok=True)
    for rel, (sha, out) in SOURCES.items():
        f = pathlib.Path(src) / pathlib.Path(rel).name
        got = hashlib.sha256(f.read_bytes()).hexdigest()
        if got != sha:
            sys.exit('FONTS %s: SHA-256 %s, want %s' % (f, got, sha))
        subset.main([str(f), '--unicodes=' + UNICODES, '--layout-features=', '--name-IDs=*', '--output-file=' + str(ROOT / 'engine/fonts' / out)])
        print('FONTS wrote engine/fonts/%s' % out)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
