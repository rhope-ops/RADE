#!/usr/bin/env python3
"""RADE engine: the parts of a bundle that come from single manifest fields (moved out of engine/rade_build.py on
2026-11-21 to keep that file under its size cap, docs/code-standard.md C4).

q quotes a PowerShell string; hand_part gives a guide step's "hide" and "answersOnly"; restore_part gives an app's
"restore" (engine-v31). engine/rade_build.py imports it. A bad field stops the build (the schema says the same).
Run target: Python 3 (the build).
Network: none.
Writes: none.
Credentials: none.
"""
import re

BACKUP_RE = r'[A-Za-z0-9]([A-Za-z0-9 _()-]*[A-Za-z0-9_)-])?'   # a list title Back up and Restore name (R39: parentheses)


def q(s):
    """Return `s` as a PowerShell single-quoted string ('' for each quote inside)."""
    return "'" + s.replace("'", "''") + "'"


def qx(s):
    """Return `s` as a PowerShell string expression with ASCII text only (a bundle is ASCII; engine-v43 L1, the
    subtitle "Kanon <bullet> ...").

    Args:
        s: the text; it may hold characters above 127.

    Returns:
        q(s) for plain ASCII; else a parenthesized sum of quoted ASCII runs and [string][char]0xNNNN parts.
    """
    if all(ord(c) < 128 for c in s):
        return q(s)
    parts, run = [], ''
    for c in s:
        if ord(c) < 128:
            run += c
            continue
        if run:
            parts.append(q(run))
            run = ''
        o = ord(c)
        units = [o] if o < 0x10000 else [0xD800 + ((o - 0x10000) >> 10), 0xDC00 + ((o - 0x10000) & 0x3FF)]   # UTF-16, as .NET strings hold it
        parts.extend('[string][char]0x%04X' % u for u in units)
    if run:
        parts.append(q(run))
    return '(' + ' + '.join(parts) + ')'


def name_spot(app, b):
    """Return the bundle lines of the logo block's application row (engine-v45, name spot L2; the PFM, 2026-11-26).

    Args:
        app: the manifest's application object (productName and subtitle are optional).
        b: the bundle (label is optional).

    Returns:
        One text with $appProduct, $appSubtitle and $roundLabel, each an ASCII PowerShell string ('' when not set).
    """
    return '\n'.join('$%s = %s' % (k, qx(v)) for k, v in (('appProduct', app.get('productName', '')), ('appSubtitle', app.get('subtitle', '')),
                                                          ('roundLabel', b.get('label', ''))))


def hand_part(s):
    """The fields "hide" and "answersOnly" of a guide step (docs/engine.md "Step contract") as a part of its $steps line.

    Args:
        s: the manifest step; a bad field stops the build (the schema says the same).

    Returns:
        '; Hide = @(...)' and/or '; AnswersOnly = $true', or ''.
    """
    def no(why):
        """Stop the build with the step name and the reason."""
        raise SystemExit('step %r: %s' % (s['name'], why))
    out, guide, hide = '', s.get('kind', 'script') == 'guide', s.get('hide')
    if 'hide' in s:
        if not guide or not isinstance(hide, list) or not 1 <= len(hide) <= 2 or len(set(hide)) != len(hide) or set(hide) - {'done', 'failed', 'skip'} or ('done' in hide and s.get('answers')):
            no('hide: only for a guide step (kind "guide"): 1 or 2 of done, failed and skip, each one time (one button stays); not done when the step has answers')
        out += '; Hide = @(%s)' % ', '.join(q(h) for h in hide)
    if 'answersOnly' in s:
        used = [f for f in ('hide', 'doneText', 'doneLog', 'marker', 'url', 'urlConfig', 'file', 'guide') if s.get(f)]
        if s['answersOnly'] is not True or not guide or not s.get('answers') or used:
            no('answersOnly: true, only for a guide step (kind "guide") with "answers" and no Done card (so without: %s)' % (', '.join(used) or 'nothing'))
        out += '; AnswersOnly = $true'
    return out


def restore_part(a):
    """The manifest field "restore" of an app (engine-v31 and v32; the Administrator, 2026-11-20 and 2026-11-21) as PowerShell.

    "testSites": the site names (the part after the site prefix) where Restore may write, or "local" (engine-v32): the
    person marks the saved site as a test site on that computer (for an app whose public repo must not hold the name).
    RADE refuses Restore on any other site. "pause" (optional): the app's pause-switch row (list, row title, field, the
    "on" value) that Restore sets before it writes and puts back after, so the app's flows can skip while rows come back
    (plan R2); a row the flows do not read yet needs no other setting (the Administrator, 2026-11-21).

    Args:
        a: the manifest app entry; a bad field stops the build (the schema says the same).

    Returns:
        '$null' when the app has no "restore" field, else '@{ TestSites = @(...); Local = $true or $false; Pause = $null or @{...} }'.
    """
    r = a.get('restore')
    if not r:
        return '$null'
    assert a.get('backup'), 'app %r: restore needs backup (Restore puts back the lists that Back up saves)' % a['name']
    sites = r.get('testSites', [])
    local = sites == 'local'
    assert local or (isinstance(sites, list) and sites and all(isinstance(n, str) and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]*', n) for n in sites)), \
        'app %r: restore.testSites: "local", or one or more site names (letters, digits, "_", "-")' % a['name']
    pause = '$null'
    pz = r.get('pause')
    if pz:
        plain = re.fullmatch(BACKUP_RE, pz['list']) and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9 _-]*', pz['title']) and re.fullmatch(r'[A-Za-z0-9_]+', pz['field'])
        assert plain, 'app %r: restore.pause list, title and field hold plain names only' % a['name']
        assert re.fullmatch(r'[A-Za-z0-9 _-]{1,40}', pz['on']), 'app %r: restore.pause.on: a plain value' % a['name']
        pause = '@{ List = %s; Title = %s; Field = %s; On = %s }' % (q(pz['list']), q(pz['title']), q(pz['field']), q(pz['on']))
    return '@{ TestSites = @(%s); Local = %s; Pause = %s }' % ('' if local else ', '.join(map(q, sites)), '$true' if local else '$false', pause)


def uninstall_part(a, b):
    """The manifest field "uninstall" of an app (engine-v40; 90-161.Z R43 E3, the PFM, 2026-11-25) as PowerShell.

    The app's own Uninstall steps, by name, in run order: steps of the bundle that are not install steps of the app
    (a script that does not read RADE_MODE would install again). Uninstall runs only on a test site (the Restore gate)
    and backs up first, so the app needs "restore" (and so "backup"), and mode deploy (it changes the install record).

    Args:
        a: the manifest app entry.
        b: the manifest bundle (its "steps").

    Returns:
        '@()' when the app has no "uninstall" field, else '@(<step index>, ...)'. A bad field stops the build.
    """
    names = [s['name'] for s in b['steps']]
    un = a.get('uninstall', [])
    if not un:
        return '@()'
    assert len(set(un)) == len(un) and all(n in names for n in un), 'app %r: uninstall: unique names of steps of this bundle' % a['name']
    assert not set(un) & set(a['steps']), 'app %r: uninstall: a step is an install step too (%s); give Uninstall its own steps' % (a['name'], ', '.join(sorted(set(un) & set(a['steps']))))
    assert a.get('mode') == 'deploy' and a.get('restore'), 'app %r: uninstall needs mode deploy and "restore" (its test sites; Uninstall backs up first)' % a['name']
    for n in un:
        s = b['steps'][names.index(n)]
        assert not s.get('after') and not s.get('ask'), 'app %r: uninstall step %r: no "after" or "ask" (Uninstall runs its steps in order and stops at the first that is not done)' % (a['name'], n)
    return '@(%s)' % ', '.join(str(names.index(n)) for n in un)
