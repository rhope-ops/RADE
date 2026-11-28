#!/usr/bin/env python3
"""Security rules of the RADE page (index.html; fleet v2). No network. Pass = last line "PAGE rules ok ...".

1. Safe DOM: the page script has no HTML sink (innerHTML, outerHTML, insertAdjacentHTML, document.write).
2. A link that opens a new tab has rel="noopener noreferrer" (in the HTML and in the script).
3. The Content-Security-Policy meta names the SHA-256 of each inline script, and has no 'unsafe-inline' for scripts.
4. A referrer meta sets no-referrer.
5. No hand-written owner value (DEC 7): "rhope-ops" appears only in a block generated from README.md, and each Teams
   channel name there equals apps.json "help".
6. Contrast (Option A, fleet v2 DEC 5), computed here, in the light and the dark theme: --control (the track edge) and
   --warn (the edge under the band) are 3:1 or more against --bg; --warn is also 4.5:1 or more (text level); a skip link
   and the two theme-color metas are there.
Usage: python3 tests/page_test.py [path]   (default: index.html). Run by scripts/check.local.sh.
Network: none.
Writes: none.
Credentials: none.
"""
import base64
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'scripts'))
import ui_tokens   # noqa: E402  the one WCAG ratio formula (scripts/ui_tokens.py)


def script_hashes(page):
    """Return the CSP source text ('sha256-...') of each inline <script> block of the page, in order.

    Args:
        page: the text of the page.

    Returns:
        A list of strings such as "'sha256-abc...='", one for each inline script.
    """
    return ["'sha256-%s'" % base64.b64encode(hashlib.sha256(body.encode('utf-8')).digest()).decode('ascii')
            for body in re.findall(r'<script>(.*?)</script>', page, re.S)]


def theme_vars(page):
    """Return the CSS custom properties of the page's light and dark theme, as set in its :root rules.

    Args:
        page: the text of the page.

    Returns:
        A dict {'light': {name: '#rrggbb'}, 'dark': {name: '#rrggbb'}}; later rules win, as in CSS.
    """
    out = {'light': {}, 'dark': {}}
    for sel, body in re.findall(r'(:root(?:\[data-theme="dark"\])?)\{([^{}]*)\}', page):
        theme = 'dark' if 'dark' in sel else 'light'
        for name, val in re.findall(r'--([\w-]+):(#[0-9a-fA-F]{6})\b', body):
            out[theme][name] = val.lower()
    return out


def contrast_problems(page):
    """Return the broken contrast rules of the page (rule 6), each ratio computed with the WCAG formula.

    Args:
        page: the text of the page.

    Returns:
        A list of plain-text lines, one for each pair below its minimum.
    """
    v = theme_vars(page)
    out = []
    for theme in ('light', 'dark'):
        c = dict(v['light'], **v[theme]) if theme == 'dark' else v['light']
        for fg, least in (('control', 3.0), ('warn', 4.5)):
            if fg not in c or 'bg' not in c:
                out.append('%s theme: no --%s or --bg' % (theme, fg))
                continue
            r = ui_tokens.ratio(c[fg], c['bg'])
            if r < least:
                out.append('%s theme: --%s %s on --bg %s is %.2f:1, below %.1f:1' % (theme, fg, c[fg], c['bg'], r, least))
    return out


def _csp_problems(page):
    """Return CSP meta problems for the page text.

    Args:
        page: the text of the page.

    Returns:
        List of plain-text error strings for missing or invalid Content-Security-Policy meta tags.
    """
    csp = re.search(r'<meta http-equiv="Content-Security-Policy" content="([^"]*)">', page)
    if not csp:
        return ['no Content-Security-Policy meta']
    out = []
    src = re.search(r'script-src ([^;]*)', csp.group(1))
    have = src.group(1).split() if src else []
    if "'unsafe-inline'" in have:
        out.append("script-src has 'unsafe-inline'")
    for want in script_hashes(page):
        if want not in have:
            out.append('script-src lacks the inline script hash: put %s in the CSP meta' % want)
    if "default-src 'none'" not in csp.group(1):
        out.append("CSP has no default-src 'none'")
    return out


def problems(page, help_name=None):
    """Return the list of broken rules of the page text (empty when every rule holds).

    Args:
        page: the text of the page.
        help_name: the Teams channel name of apps.json, or None to skip that rule.

    Returns:
        A list of plain-text lines, one for each broken rule.
    """
    out = []
    scripts = ''.join(re.findall(r'<script>(.*?)</script>', page, re.S))
    for sink in ('innerHTML', 'outerHTML', 'insertAdjacentHTML', 'document.write'):
        if sink in scripts:
            out.append('HTML sink in the page script: ' + sink)
    for tag in re.findall(r'<a\b[^>]*target="_blank"[^>]*>', page):
        if 'rel="noopener noreferrer"' not in tag:
            out.append('new-tab link without rel="noopener noreferrer": ' + tag[:80])
    if re.search(r"target:'_blank'(?![^}]*rel:'noopener noreferrer')", scripts):
        out.append("script link with target '_blank' and no rel 'noopener noreferrer'")
    out += _csp_problems(page)
    if '<meta name="referrer" content="no-referrer">' not in page:
        out.append('no referrer meta with no-referrer')
    hand = re.sub(r'<!-- >>> site:.*?<!-- <<< site:[\w-]+ -->', '', page, flags=re.S)   # the parts not made from README.md
    if re.search(r'rhope-ops', hand, re.I):
        out.append('a hand-written rhope-ops value: take it from apps.json (DEC 7)')
    if help_name is not None:
        for name in re.findall(r'Teams channel <(?:strong|b)>([^<]*)</', page):
            if name != help_name:
                out.append('the Teams channel %r differs from apps.json help %r' % (name, help_name))
    if 'class="skip-link"' not in page:
        out.append('no skip link')
    if len(re.findall(r'<meta name="theme-color" content="#[0-9a-fA-F]{6}" media="\(prefers-color-scheme: (?:light|dark)\)">', page)) != 2:
        out.append('not two theme-color metas (light and dark)')
    return out + contrast_problems(page)


def self_test():
    """Prove that each rule finds its break, on small pages made here."""
    good = ('<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; script-src %s">'
            '<meta name="referrer" content="no-referrer"><a class="skip-link" href="#m">s</a>'
            '<meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)">'
            '<meta name="theme-color" content="#000000" media="(prefers-color-scheme: dark)">'
            '<style>:root{--bg:#ffffff;--control:#6c7b8e;--warn:#8a5a00}:root[data-theme="dark"]{--bg:#0e141c;--control:#8794a6;--warn:#f2c14e}</style>'
            '<script>x()</script>')
    ok = good % script_hashes('<script>x()</script>')[0]
    assert problems(ok) == [], problems(ok)
    assert problems(ok.replace('x()', 'y()'))                                       # a changed script: the hash differs
    assert problems(ok.replace('x()', 'e.innerHTML=1'))                             # a sink
    assert problems(ok + '<a href="h" target="_blank" rel="noopener">')              # rel without noreferrer
    assert problems(ok.replace('no-referrer', 'origin'))                            # no referrer rule
    assert problems(ok.replace("default-src 'none'; ", ''))                         # no default-src
    assert problems(ok + '<a href="https://github.com/rhope-ops/x">')                # a hand-written owner value
    assert problems(ok + 'Teams channel <b>X</b>', 'Y') and not problems(ok + 'Teams channel <b>Y</b>', 'Y')
    assert round(ui_tokens.ratio('#777777', '#FFFFFF'), 2) == 4.48                     # the WCAG formula itself
    assert problems(ok.replace('--control:#6c7b8e', '--control:#e3e8ee'))              # a track edge of 1.2:1
    assert problems(ok.replace('--warn:#f2c14e', '--warn:#5a4a20'))                    # dark warn too dark
    assert problems(ok.replace('class="skip-link"', 'class="x"'))                      # no skip link


if __name__ == '__main__':
    self_test()
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'index.html'
    help_name = json.loads((ROOT / 'apps.json').read_text(encoding='utf-8')).get('help', '')
    bad = problems(path.read_text(encoding='utf-8'), help_name)
    for line in bad:
        print('FAIL ' + line)
    if bad:
        sys.exit(1)
    print('PAGE rules ok: 0 HTML sinks, CSP script hash matches, no-referrer, 0 hand-written owner values, contrast pairs=4')
