#!/usr/bin/env python3
"""Self-test of tests/check_code_standard.py (run by `python3 tests/check_code_standard.py --self-test`; kept in its
own file so the check stays under the 600-line cap of docs/code-standard.md C4).

It builds small sample repos in a temporary folder and proves each rule of the check: clean files pass; a function
without a comment, a long function, a grown function, a fixed item left in the baseline, a missing header, a shell
`${#..}` function, JS functions and methods, a PowerShell parse error, a divider line above a function, a long
argument script block, a shebang file with no extension and two same bodies; and the comparison with origin/main.
Input: the check module. Output: one "pass" line, or an AssertionError naming the rule. Needs git and pwsh 7.
This file is the same in rhope-ops/RADE and rhope-ops/90-161.Z.
"""
import json
import subprocess
import tempfile
from pathlib import Path


def run(cs):
    """Prove the check (the module `cs`) on a sample repo in a temporary folder: clean files pass; a new debt, a grown function and an
    unlowered fixed item each fail; --update refuses new debt; a marked generated block is skipped."""
    good_py = '"""Sample module: it shows a file that meets every rule of the code standard."""\n\n\n' \
              'def add(a, b):\n    """Return a + b."""\n    return a + b\n'
    good_ps = '<#\n  Sample PowerShell file: it shows a file that meets every rule of the code standard.\n#>\n' \
              '# Returns the text in capitals.\nfunction Get-Upper([string]$T) {\n  return $T.ToUpper()\n}\n' \
              '# >>> shared: generated from src/shared.ps1 by build.py (do not edit)\n' \
              'function Get-Copy { return 1 }\n# <<< shared\n'
    with tempfile.TemporaryDirectory() as d:
        cs.ROOT = ROOT = Path(d)
        cs.BASELINE = ROOT / 'tests' / 'code-standard-baseline.json'
        (ROOT / 'tests').mkdir()
        g = lambda *c: subprocess.run(['git', '-C', d, *c], check=True, capture_output=True)
        g('init', '-q')
        (ROOT / 'a.py').write_text(good_py)
        (ROOT / 'b.ps1').write_text(good_ps)
        config = {'caps': {'max_function_lines': 5, 'max_file_lines': 50}, 'include': ['*'], 'exclude': [], 'generated': []}
        g('add', '.')
        m = cs.measure(config)
        assert not any(m['violations'].values()), 'clean files pass: %s' % m['violations']
        assert [f['name'] for f in m['files']['b.ps1']['functions']] == ['Get-Upper'], 'generated block skipped'
        (ROOT / 'a.py').write_text(good_py + '\n\ndef bare(x):\n    return x\n')
        new, fixed = cs.compare(cs.measure(config)['violations'], {}, config['caps'])
        assert len(new) == 1 and 'C2' in new[0] and 'a.py::bare' in new[0], 'a function without a comment fails: %s' % new
        long_fn = '\n\ndef long(x):\n    """Long."""\n' + '    x += 1\n' * 6 + '    return x\n'
        (ROOT / 'a.py').write_text(good_py + long_fn)
        debt = cs.measure(config)['violations']
        assert debt['length'] == {'a.py::long': 9}, 'a long function is debt: %s' % debt['length']
        (ROOT / 'a.py').write_text(good_py + long_fn.replace('    return x', '    x += 1\n    return x'))
        new, fixed = cs.compare(cs.measure(config)['violations'], debt, config['caps'])
        assert len(new) == 1 and 'grew from 9 to 10' in new[0], 'a listed function that grew fails: %s' % new
        (ROOT / 'a.py').write_text(good_py)
        new, fixed = cs.compare(cs.measure(config)['violations'], debt, config['caps'])
        assert not new and len(fixed) == 1, 'a fixed item is reported (and fails until the baseline is lowered)'
        (ROOT / 'c.sh').write_text('echo hi\n')
        g('add', '.')
        new, _ = cs.compare(cs.measure(config)['violations'], {}, config['caps'])
        assert any('C1' in x and 'c.sh' in x for x in new), 'a file without a header fails: %s' % new
        self_test_kinds(cs, ROOT, g, config)
        self_test_main(cs, ROOT, g)
    print('code standard self-test: pass')
    return 0


def self_test_kinds(cs, root, g, config):
    """Self-test of the finding kinds: a shell `${#..}` function is measured whole, a JS function and method are found,
    a PowerShell parse error fails, a header or divider line is not a function's comment, a long argument script block
    is measured, a shebang file with no extension is checked, and two same bodies are duplicates."""
    sh = '#!/usr/bin/env bash\n# Sample shell file: it shows how functions are measured by the check.\n# Counts.\nf() {\n  n=${#a[@]}\n' \
         + '  x=1\n' * 6 + '}\n'
    (root / 'c.sh').write_text(sh)
    js = '// Sample JavaScript file: it shows how functions and methods are found by the check.\n' \
         'function plain(a) {\n  return a;\n}\nclass K {\n  // Adds one.\n  inc(x) {\n    return x + 1;\n  }\n}\n'
    (root / 'd.js').write_text(js)
    (root / 'e.ps1').write_text('<#\n  Sample PowerShell file with a parse error, for the check self-test only.\n#>\n$x = (1 + \n')
    blk = '<#\n  Sample PowerShell file: a long script block passed to a call, for the check self-test only.\n#>\n' \
          '# ---- a divider\nfunction Get-NoDoc { return 1 }\n$b.Add_Click({\n' + '  $y = 1\n' * 6 + '})\n'
    (root / 'f.ps1').write_text(blk)
    (root / 'hook').write_text('#!/bin/sh\necho no header here\n')
    dup = '"""Sample module with two same bodies, for the check self-test only (rule C5)."""\n\n\n' + ''.join(
        'def %s(x):\n    """Same body."""\n    y = x + 1\n    y = y * 2\n    y = y - 3\n    return y\n\n\n' % n for n in ('one', 'two'))
    (root / 'g.py').write_text(dup)
    g('add', '.')
    v = cs.measure(config)['violations']
    assert v['length'].get('c.sh::f') == 9, 'shell ${#..}: the whole function is measured: %s' % v['length']
    assert 'd.js::plain' in v['comment'] and 'd.js::inc' not in v['comment'], 'JS function and method: %s' % v['comment']
    assert v['parse'].get('e.ps1', 0) >= 1, 'a PowerShell parse error fails: %s' % v['parse']
    assert 'f.ps1::Get-NoDoc' in v['comment'], 'a divider line is not a comment: %s' % v['comment']
    assert any(k.startswith('f.ps1::{block in $b.Add_Click') for k in v['length']), 'a long argument block: %s' % v['length']
    assert 'hook' in v['header'], 'a shebang file with no extension is checked: %s' % v['header']
    assert set(v['duplicate']) == {'g.py::one', 'g.py::two'}, 'two same bodies are duplicates: %s' % v['duplicate']
    for f in ('c.sh', 'd.js', 'e.ps1', 'f.ps1', 'hook', 'g.py'):
        (root / f).unlink()
    g('add', '-A')


def self_test_main(cs, root, g):
    """Self-test of the comparison with main: an item added by hand and a raised cap fail; a cap change with a
    DECISIONS row that names the baseline passes."""
    cs.BASELINE = root / 'tests' / 'code-standard-baseline.json'
    base = {'config': {'caps': {'max_function_lines': 5, 'max_file_lines': 50}}, 'debt': {'comment': {'a.py::x': 1}}}
    cs.BASELINE.write_text(json.dumps(base))
    (root / 'docs').mkdir()
    (root / 'docs' / 'DECISIONS.md').write_text('# Decisions\n')
    g('add', '.')
    g('-c', 'user.email=t@t', '-c', 'user.name=t', 'commit', '-qm', 'base')
    g('update-ref', 'refs/remotes/origin/main', 'HEAD')
    assert cs.against_main(base)[0] == [], 'the same baseline passes'
    added = {'config': base['config'], 'debt': {'comment': {'a.py::x': 1, 'a.py::y': 1}}}
    assert 'added by hand' in ' '.join(cs.against_main(added)[0]), 'an item added by hand fails'
    raised = {'config': {'caps': {'max_function_lines': 9, 'max_file_lines': 50}}, 'debt': base['debt']}
    assert 'config' in ' '.join(cs.against_main(raised)[0]), 'a raised cap fails'
    (root / 'docs' / 'DECISIONS.md').write_text('# Decisions\n| cap 9 | tests/code-standard-baseline.json |\n')
    assert cs.against_main(raised)[0] == [], 'a cap change with a DECISIONS row passes'
