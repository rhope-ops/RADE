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

    # Fonts an app's build copies from the engine (the Administrator, 2026-11-21): put in from the engine, nothing else.
    fm = {'bundles': [{'files': [{'src': 'assets/fonts/build/90161Z-OFL.txt'}, {'src': 'assets/fonts/build/90161Z-Nope.ttf'},
                                 {'src': 'assets/fonts/build/90161Z-Here.ttf'}, {'src': '../fonts/build/X-OFL.txt'}, {'src': 'docs/OFL.txt'}]}]}
    (t / 'assets/fonts/build').mkdir(parents=True); (t / 'assets/fonts/build/90161Z-Here.ttf').write_bytes(b'app')
    fake = {'OFL.txt': b'licence', 'Here.ttf': b'engine'}
    got = c.stage_fonts(t, fm, fake.get)
    assert got == ['assets/fonts/build/90161Z-OFL.txt'], got
    assert (t / 'assets/fonts/build/90161Z-OFL.txt').read_bytes() == b'licence' and (t / 'assets/fonts/build/90161Z-Here.ttf').read_bytes() == b'app'
    assert not (t / 'assets/fonts/build/90161Z-Nope.ttf').exists() and not (t.parent / 'fonts').exists() and not (t / 'docs').exists()
    assert c.this_font('OFL.txt') and c.this_font('none.ttf') is None and c.this_font('../rade_build.py') is None
    # A file where a folder should be: no stop, the build names it. The locked engine: a font file, never a folder or a bad name.
    (t / 'bad').write_text('x')
    assert c.stage_fonts(t, {'bundles': [{'files': [{'src': 'bad/fonts/build/X-OFL.txt'}]}]}, fake.get) == []
    head = c.run(['git', 'rev-parse', 'HEAD'], c.ROOT)[1]
    assert c.locked_font(head, 'OFL.txt') == c.this_font('OFL.txt') and c.locked_font(head, 'none.ttf') is None and c.locked_font(head, '../rade_build.py') is None
    real = c.git_type; c.git_type = lambda commit, rel: 'tree'   # a folder at that path: never read as a font
    try:
        assert c.locked_font(head, 'OFL.txt') is None
    finally:
        c.git_type = real
    assert c.git_type(head, 'engine/fonts') == 'tree' and c.git_type(head, 'engine/fonts/OFL.txt') == 'blob'
    assert not list((t / 'assets/fonts/build').glob('.rade-font-*'))   # no temporary file left after a copy
    # A move that fails: no font and no temporary file stay; an app file with a similar name is not touched.
    (t / 'assets/fonts/build/90161Z-OFL.txt').unlink(); (t / 'assets/fonts/build/90161Z-OFL.txt.part').write_bytes(b'APPFILE')
    real_replace = c.os.replace
    def no_replace(a, b):
        raise OSError('disk full')
    c.os.replace = no_replace
    try:
        assert c.stage_fonts(t, fm, fake.get) == []
    finally:
        c.os.replace = real_replace
    assert not (t / 'assets/fonts/build/90161Z-OFL.txt').exists() and not list((t / 'assets/fonts/build').glob('.rade-font-*'))
    assert (t / 'assets/fonts/build/90161Z-OFL.txt.part').read_bytes() == b'APPFILE'

print('CANARY rules ok: %d bad manifest paths, %d bad locks, 1 symbolic link, 1 no-reconnaissance note, 1 font put in' % (len(muts), len(bads)))
