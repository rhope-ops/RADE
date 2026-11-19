#!/usr/bin/env python3
"""Rules of the app canary (scripts/check_apps.py) for content from an app repository: no path leaves its folder, a lock
names an engine among its own files, a symbolic link is found, and a no-reconnaissance word in a built bundle gives a NOTE line. No network. Pass = last line "CANARY rules ok ...".
Run by scripts/check.local.sh."""
import copy, json, os, sys, tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'scripts'))
import check_apps as c

m = {'application': {'knownDirs': [['scripts/gov', '*.ps1']]},
     'bundles': [{'out': 'o.ps1', 'files': [{'src': 'a'}], 'fetch': [{'url': 'x', 'name': 'n'}],
                  'steps': [{'default': {'passed': 'h', 'paths': ['a']}}, {'default': False}]}]}
assert c.unsafe_paths(m) == [], c.unsafe_paths(m)
muts = [lambda x: x['application']['knownDirs'].append(['../x', '*']),
        lambda x: x['application']['knownDirs'].append(['/etc', '*']),
        lambda x: x['application']['knownDirs'].append(['scripts', '../../*']),
        lambda x: x['application']['knownDirs'].append(['scripts']),
        lambda x: x['bundles'][0].__setitem__('out', '../o'),
        lambda x: x['bundles'][0]['files'].append({'src': '/etc/passwd'}),
        lambda x: x['bundles'][0]['fetch'].append({'src': 'a/../../b'}),
        lambda x: x['bundles'][0]['steps'][0]['default']['paths'].append('../k'),
        lambda x: x['bundles'][0]['files'].append({'src': 'C:\\x'})]
for mut in muts:
    y = copy.deepcopy(m); mut(y)
    assert len(c.unsafe_paths(y)) == 1, y

with tempfile.TemporaryDirectory() as t:
    t = Path(t); (t / 'scripts').mkdir(); lk = t / 'scripts/rade.lock.json'
    assert c.read_lock(t, 'scripts/m.json') is None
    good = {'commit': 'a' * 40, 'engine': 'engine/rade_build.py', 'files': {'engine/rade_build.py': 'x'}}
    lk.write_text(json.dumps(good))
    assert c.read_lock(t, 'scripts/m.json') == ('a' * 40, 'engine/rade_build.py', ['engine/rade_build.py'])
    bads = [{**good, 'engine': '../evil.py'}, {**good, 'engine': '/tmp/evil.py'}, {**good, 'engine': 'other.py'}, {**good, 'engine': 'scripts/check.sh', 'files': {'scripts/check.sh': 'x'}},
            {**good, 'files': {'engine/rade_build.py': 'x', '../y': 'z'}}, {**good, 'commit': 'main'}, {'x': 1}]
    for bad in bads:
        lk.write_text(json.dumps(bad))
        try:
            c.read_lock(t, 'scripts/m.json')
        except LookupError:
            continue
        sys.exit('FAIL a bad lock was accepted: %r' % bad)
    os.symlink('/etc', t / 'lnk')
    assert c.links(t) == ['lnk'], c.links(t)
    # A built bundle with a word of the "No reconnaissance" rule gives one NOTE line; a clean or missing bundle gives none.
    (t / 'o.ps1').write_text("'ok'\nTest-NetConnection $h\n")
    assert c.recon_notes(t, m) == ['no-reconnaissance word to review: o.ps1:2: host or port test: Test-NetConnection'], c.recon_notes(t, m)
    (t / 'o.ps1').write_text("'ok'\n")
    assert c.recon_notes(t, m) == [] and c.recon_notes(t / 'none', m) == []

print('CANARY rules ok: %d bad manifest paths, %d bad locks, 1 symbolic link, 1 no-reconnaissance note' % (len(muts), len(bads)))
