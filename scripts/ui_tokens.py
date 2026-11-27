#!/usr/bin/env python3
"""UI standard v1 checks (the Administrator, 2026-11-20; docs/ui-standard.md B10, B11): contrast and the page's colors.

1. Contrast: every pair of engine/ui-tokens.json "pairs" (the light set) and "dark"."pairs" (the dark set, plan engine-v48
   D6) meets WCAG 2.2: text at least 4.5:1 (1.4.3), non-text at least 3:1 (1.4.11), computed from the hex values with
   the WCAG relative luminance.
2. The RADE page (index.html): its light colors and its contrast blocks are written from the same tokens, between the
   marks of PAGE_BLOCKS (the dark scheme stays the page's own). --write writes them; the check fails when they are old.
3. The self-test: a known pair (black on white = 21:1, #777 on white = 4.48:1) proves the formula first.

Usage: python3 scripts/ui_tokens.py [--write]   Pass = last line "UI-TOKENS pass pairs=N" (N: both sets).
Run target: Python 3.
Network: none.
Writes: index.html (--write only).
Credentials: none.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOKENS = ROOT / 'engine/ui-tokens.json'
PAGE = ROOT / 'index.html'
NEED = {'text': 4.5, 'non-text': 3.0}   # WCAG 2.2 SC 1.4.3 and 1.4.11
# The page's color variables and the token each one is (the page keeps its own names).
PAGE_VARS = [('bg', 'White'), ('navy', 'Navy'), ('text', 'Ink'), ('gray', 'Gray'), ('action', 'Blue'), ('action-fg', 'OnBlue'),
             ('link', 'Link'), ('turn', 'Yellow'), ('fail', 'Red'), ('pass', 'Green'), ('edge', 'Edge'), ('track', 'Hair'), ('btn', 'Face')]
# The CSS system color of each SystemColors role (CSS Color 4 system colors), for forced-colors.
CSS_SYSTEM = {'Window': 'Canvas', 'WindowText': 'CanvasText', 'GrayText': 'GrayText', 'Highlight': 'Highlight',
              'HighlightText': 'HighlightText', 'HotTrack': 'LinkText', 'ButtonFace': 'ButtonFace', 'ButtonText': 'ButtonText',
              'Control': 'ButtonFace', 'ControlText': 'ButtonText'}
FONT_STACK = '"Sofia Sans","Segoe UI",system-ui,-apple-system,Roboto,sans-serif'
TITLE_STACK = '"Sofia Sans Condensed","Segoe UI",system-ui,-apple-system,Roboto,sans-serif'


def luminance(hexcolor):
    """Return the WCAG relative luminance of a #RRGGBB color."""
    c = [int(hexcolor[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]
    c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def ratio(a, b):
    """Return the WCAG contrast ratio of two #RRGGBB colors (1 to 21)."""
    hi, lo = sorted((luminance(a), luminance(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def page_blocks(t):
    """Return {mark: CSS text} for the two generated blocks of index.html.

    Args:
        t: the tokens (engine/ui-tokens.json).

    Returns:
        The light colors and fonts (mark 'ui-tokens') and the contrast blocks (mark 'ui-tokens-contrast').
    """
    col = t['colors']
    light = ';'.join('--%s:%s' % (v, col[k]['hex'].lower()) for v, k in PAGE_VARS)
    forced = ';'.join('--%s:%s' % (v, CSS_SYSTEM[col[k]['system']]) for v, k in PAGE_VARS)
    # plain :root (no higher specificity), so the page's own hand-written contrast rules after this block win where they differ
    more = '--gray:%s;--edge:%s;--track:%s' % (col['Ink']['hex'].lower(), col['Navy']['hex'].lower(), col['Track']['hex'].lower())
    return {
        'ui-tokens': ':root{%s;\n--ui:%s;--title:%s;--mono:Consolas,"Cascadia Mono",ui-monospace,monospace}' % (light, FONT_STACK, TITLE_STACK),
        'ui-tokens-contrast': '@media (prefers-contrast:more){:root{%s}}\n'
                              '@media (forced-colors:active){:root,:root[data-theme]{%s}}' % (more, forced),
    }


def spliced(text, blocks):
    """Return the page text with each generated block replaced, or None when a mark is missing."""
    for mark, css in blocks.items():
        a, b = '/* >>> %s: generated from engine/ui-tokens.json by scripts/ui_tokens.py --write (do not edit) */' % mark, '/* <<< %s */' % mark
        i, j = text.find(a), text.find(b)
        if i < 0 or j < i:
            return None
        text = text[:i + len(a)] + '\n' + css + '\n' + text[j:]
    return text


def main(write):
    """Prove the formula, check every pair, then check (or write) the page. Exits 1 on a failure.

    Args:
        write: True to write the page's generated blocks (--write), False to check them.
    """
    bad = []
    if round(ratio('#000000', '#FFFFFF'), 2) != 21.0 or round(ratio('#777777', '#FFFFFF'), 2) != 4.48:
        bad.append('the contrast formula fails its self-test')
    t = json.loads(TOKENS.read_text(encoding='utf-8'))
    light = {k: c['hex'] for k, c in t['colors'].items()}
    sets = [('light', light, t['pairs']), ('dark', t['dark']['colors'], t['dark']['pairs'])]
    for name, hexes, pairs in sets:
        for p in pairs:
            r = ratio(hexes[p['fg']], hexes[p['bg']])
            print('CONTRAST %s %s on %s (%s): %.2f:1, need %.1f:1' % (name, p['fg'], p['bg'], p['kind'], r, NEED[p['kind']]))
            if r < NEED[p['kind']]:
                bad.append('%s: %s on %s is %.2f:1, the %s minimum is %.1f:1' % (name, p['fg'], p['bg'], r, p['kind'], NEED[p['kind']]))
    page = PAGE.read_text(encoding='utf-8')
    new = spliced(page, page_blocks(t))
    if new is None:
        bad.append('index.html lacks a generated block mark (ui-tokens, ui-tokens-contrast)')
    elif write and new != page:
        PAGE.write_text(new, encoding='utf-8')
        print('UI-TOKENS wrote index.html')
    elif new != page:
        bad.append('index.html: the colors are old: run python3 scripts/ui_tokens.py --write')
    for b in bad:
        print('FAIL ' + b)
    print('UI-TOKENS %s pairs=%d' % ('fail' if bad else 'pass', sum(len(x[2]) for x in sets)))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main(sys.argv[1:] == ['--write'])
