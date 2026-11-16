#!/usr/bin/env python3
"""Check RADE manifests against schemas/rade-manifest.schema.json, plus the cross-references a schema cannot express.
Usage: python3 scripts/check_manifest.py [manifest.json ...]   (default: schemas/examples/*.json)
Pass = last line "MANIFEST files=N fail=0". Needs jsonschema (PyPI) 4.x.
"""
import json, sys
from pathlib import Path
try:
    from jsonschema import Draft202012Validator
except ImportError:
    sys.exit('FAIL jsonschema is missing: pip install "jsonschema>=4,<5"')

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = json.loads((ROOT / 'schemas/rade-manifest.schema.json').read_text())
Draft202012Validator.check_schema(SCHEMA)
VALIDATOR = Draft202012Validator(SCHEMA)


def refs(m):
    """Errors the schema cannot find: step files, unique step names and answer keys, app and collect step names."""
    out = []
    for b in m.get('bundles', []):
        r = b.get('round', '?')
        have = {(f['dir'], Path(f['src']).name) for f in b.get('files', [])}
        names = [s['name'] for s in b.get('steps', [])]
        if len(names) != len(set(names)):
            out.append('%s: step names are not unique' % r)
        for s in b.get('steps', []):
            if not s['file'] and s.get('kind') != 'guide':
                out.append('%s: step %r: only a guide step may have no file' % (r, s['name']))
            elif s['file'] and (s['dir'], s['file']) not in have:
                out.append('%s: step %r: %s/%s is not in files' % (r, s['name'], s['dir'], s['file']))
            if 'answers' in s and s.get('kind') != 'guide':
                out.append('%s: step %r: answers: only a guide step (kind "guide") can ask questions' % (r, s['name']))
            qs = s.get('answers') if isinstance(s.get('answers'), list) else []
            keys = [a['key'] for a in qs if isinstance(a, dict) and isinstance(a.get('key'), str)]
            for k in sorted({k for k in keys if keys.count(k) > 1}):
                out.append('%s: step %r: answers: the key %r is used twice' % (r, s['name'], k))
            for a in qs:
                # the schema counts spaces; the window shows the text trimmed, so a text of only spaces is empty
                if isinstance(a, dict) and isinstance(a.get('prompt'), str) and not a['prompt'].strip():
                    out.append('%s: step %r: answers: the prompt of %r is empty (only spaces)' % (r, s['name'], a.get('key')))
                if isinstance(a, dict) and any(isinstance(c, str) and not c.strip() for c in (a.get('choices') if isinstance(a.get('choices'), list) else [])):
                    out.append('%s: step %r: answers: a choice of %r is empty (only spaces)' % (r, s['name'], a.get('key')))
                cs = a.get('choices') if isinstance(a, dict) and isinstance(a.get('choices'), list) else []
                low = [c.strip().lower() for c in cs if isinstance(c, str)]
                if len(set(low)) != len(low):
                    out.append('%s: step %r: answers: the choices of %r must differ (case and spaces ignored)' % (r, s['name'], a.get('key')))
        for a in b.get('apps', []):
            for n in a['steps']:
                if n not in names:
                    out.append('%s: app %r: unknown step %r' % (r, a['name'], n))
        for c in b.get('collect', []):
            if c.get('step') and c['step'] not in names:
                out.append('%s: collect %r: unknown step %r' % (r, c['name'], c['step']))
    return out


def main(paths):
    paths = paths or sorted(str(p) for p in (ROOT / 'schemas/examples').glob('*.json'))
    fail = 0
    for p in paths:
        m = json.loads(Path(p).read_text())
        errs = ['%s: %s' % ('/'.join(str(x) for x in e.absolute_path) or '(root)', e.message)
                for e in sorted(VALIDATOR.iter_errors(m), key=lambda e: list(map(str, e.absolute_path)))]
        errs += refs(m)
        print(('PASS ' if not errs else 'FAIL ') + p)
        for e in errs:
            print('  ' + e)
        fail += bool(errs)
    print('MANIFEST files=%d fail=%d' % (len(paths), fail))
    return 1 if fail else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
