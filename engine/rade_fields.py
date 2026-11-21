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
