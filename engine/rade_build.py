#!/usr/bin/env python3
"""RADE engine: build an application's round bundles from its RADE manifest (schemas/rade-manifest.schema.json).

Moved from rhope-ops/90-161.Z (the Administrator, 2026-11-14). App facts come from the manifest "application" block;
RADE's own logo is assets/logo/rho-fulcrum-128.png (Rho Fulcrum from engine-v28; Rho Bold from engine-v10 to v27).

A bundle is one PowerShell text (RADE, PFM 14 Nov 26; Windows PowerShell 5.1) that the PFM pastes into Windows PowerShell
ISE and runs with F5: it writes the app's files, runs the checks and the steps, saves the round state after each step, and
writes the results folder for one Outlook draft (test) or the install record (deploy). Each part: docs/engine.md.
The window (the Administrator, 2026-11-14, "One thing"; docs/window-design.md) shows one statement or one question at a
time: the application, a check that failed or needs you, the plan, the run, a step you do by hand, the result. All
checks, the step boxes, the files, the made list and the log are in Details (F2). The Local checks run when the window
opens, so an application that cannot run on this computer cannot be chosen. All text the PFM sees is plain, simple
English (PFM 14 Nov 26). The bars are drawn by RADE (still when Windows animations are off). There is no Exit button:
the window's X asks first only while a step runs.
A catalog app of mode deploy (deploy v1, docs/engine.md; the Administrator 14 Nov 26) sends nothing: no draft, no saved
address; it updates the app's own record file in RADE\\Config\\installed (the version installed and the last deploy run).
It runs only the steps embedded in it and never fetches code (PFM 3A). If no window can open (no Windows Forms),
it runs the same steps as text.
Text files are embedded as readable single-quoted here-strings, so anyone can read the code.
The build id (first 8 hex of the sha256 of the bundle body) shows in the window title and the summary.
Usage: python3 engine/rade_build.py --app-root DIR [--manifest scripts/paste_bundles.json] [--check] [--sha]
  --check: exit 1 if a bundle is out of date. --sha: print the engine's sha256 (every engine file, see ENGINE_SHA).
"""
import base64, hashlib, json, re, sys, textwrap
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent)); import rade_hash, rade_tokens, rade_fields   # the bundle hash; the UI tokens and fonts (UI standard v1); the manifest field parts
from rade_fields import q, hand_part, restore_part, BACKUP_RE
from rade_parts import (WINDOW_FILE, ENGINE_DIR, ENGINE_PARTS, WINDOW_PARTS, WINDOW_SLOT, indent, file_sha, engine_text, ENGINE, BASE_CHECKS, CHECK_IDS, START_RE,
    WIN_RESERVED, word_list, BANNER, SHARED_RE, SHARED_LINE, shared_blocks, window_values, site_values, logo_path, SCRIPT_EXTS, ends_in, collect_problems, part_lines,
    run_steps)   # engine/rade_parts.py

ENGINE_ROOT = Path(__file__).resolve().parent.parent
LOGO = ENGINE_ROOT / logo_path()   # RADE's own logo (engine/window.json "logo"): the window and its title-bar icon (Fulcrum, the PFM, 2026-11-20)
UI_FILES = [ENGINE_ROOT / 'engine/rade_ui.ps1', ENGINE_ROOT / 'engine/rade_ui_text.ps1']   # in this order; the shared UI file (R28; docs/engine.md "How an app gets the engine")
ROOT = None   # the application repo root (--app-root)
TEXT = {'.ps1', '.json', '.txt', '.md', '.csv'}


def step_default(s):
    """A step's default tick. "default" may be true/false, or {"passed": <hash>, "paths": [...]}: then the step is on
    only when those files changed since the round that last passed it (PFM 14 Nov 26: no repeat render test)."""
    d = s.get('default', True)
    if isinstance(d, dict):
        return files_hash(d['paths']) != d['passed']
    return bool(d)


def files_hash(paths):
    """Return the first 16 hex of one SHA-256 over the given app files (path, then bytes, in path order)."""
    h = hashlib.sha256()
    for rel in sorted(paths):
        h.update(rel.encode() + b'\0' + (ROOT / rel).read_bytes() + b'\0')
    return h.hexdigest()[:16]

def here(text):
    """Return `text` as a PowerShell single-quoted here-string (@' ... '@), with LF line ends. Stops the build when a
    line starts with '@ (it would end the here-string) or the text is not ASCII."""
    text = text.replace('\r\n', '\n')
    if text.endswith('\n'):
        text = text[:-1]
    for line in text.split('\n'):
        if line.startswith("'@"):
            raise SystemExit("cannot embed: a line starts with '@")
    if any(ord(c) > 127 for c in text):
        raise SystemExit('cannot embed: non-ASCII text (keep sources ASCII)')
    return "@'\n" + text + "\n'@"


def app_lines(b):
    """The embedded catalog (PFM 14 Nov 26: the chooser lists only applications inside the paste; no fetch, PFM 3A).
    "apps" in the JSON: [{name, summary, steps: [step names]}]; without it, one application with every step."""
    names = [s['name'] for s in b['steps']]
    apps = b.get('apps') or [{'name': b.get('app', APP['name']), 'summary': b['title'], 'steps': names}]
    out = []
    for a in apps:
        idx = [names.index(n) for n in a['steps']]
        mode, version = a.get('mode', 'test'), a.get('version', '')
        assert mode != 'deploy' or version, 'app %r: a deploy needs a version' % a['name']
        # A deploy sends nothing (deploy v1, the Administrator 14 Nov 26), so it needs no Outlook check.
        need = set(BASE_CHECKS) - ({'outlook'} if mode == 'deploy' else set())
        for i in idx:
            for n in b['steps'][i].get('needs', []):
                assert n in CHECK_IDS, 'unknown check %r in step %r' % (n, names[i])
                need.add(n)
        checks = [c for c in CHECK_IDS if c in need]
        # "after": each step a step needs is in this app and runs before it. In a deploy, automatic steps come first
        # (deploy v1 item 3): a script step may follow a hand (guide) step only when it needs that step, directly or not.
        byname = {names[i]: b['steps'][i] for i in idx}
        def reach(n, seen=None):
            seen = seen if seen is not None else set()
            for d in byname[n].get('after', []):
                if d not in seen:
                    seen.add(d); reach(d, seen)
            return seen
        hand = []
        for i in sorted(idx):
            s = b['steps'][i]
            for d in s.get('after', []):
                if d not in byname or names.index(d) >= i:
                    raise SystemExit('app %r: step %r needs %r (after), which is not an earlier step of this app' % (a['name'], names[i], d))
            if s.get('kind') == 'guide':
                hand.append(names[i])
            elif mode == 'deploy' and hand and not (reach(names[i]) & set(hand)):
                raise SystemExit('app %r: automatic step %r comes after the hand step %r but does not need it: move it before, or name the step it needs in "after"' % (a['name'], names[i], hand[0]))
        mk = a.get('marker')   # the app's install record on the site (one row of its own list); plain names (a command line, a CAML query)
        marker = '$null'
        if mk:
            assert (re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9 ]*', mk['list']) and re.fullmatch(r'[A-Za-z0-9]+', mk['key'])
                    and re.fullmatch(r'[A-Za-z0-9_]+', mk['field'])), 'app %r: marker list, key and field hold letters and digits only' % a['name']
            assert mode == 'deploy' and 'site-rights' in need, 'app %r: a marker needs mode deploy and a step that needs site-rights' % a['name']
            marker = '@{ List = %s; Key = %s; Field = %s }' % (q(mk['list']), q(mk['key']), q(mk['field']))
        start = a.get('start', '')   # (R28) the app's start script, a plain relative .ps1 path in its install folder; Start runs it after the checks
        assert not start or START_RE.fullmatch(start), 'app %r: start must be a relative .ps1 path of plain names (letters, digits, space, ".", "_", "-"), for example App/Start-App.ps1' % a['name']
        backup = a.get('backup', [])   # (2026-11-20) the app's own lists Back up saves; plain names (a command line); RADE never finds lists
        # (2026-11-21, R39) a title may hold parentheses ("Name (Form 1)"): no quote, "|" or path sign, so it stays safe in a command line and a file name
        ok = all(re.fullmatch(BACKUP_RE, n) for n in backup) and not {n.upper() for n in backup} & WIN_RESERVED
        assert ok and len({n.lower() for n in backup}) == len(backup), 'app %r: backup: unique plain titles (letters, digits, space, "_", "-", "(", ")"), not a name Windows reserves' % a['name']
        out.append('$apps += @{ Name = %s; Summary = %s; Steps = @(%s); Checks = @(%s); Mode = %s; Version = %s; Marker = %s; Start = %s; Backup = @(%s); Restore = %s }'
                   % (q(a['name']), q(a['summary']), ', '.join(map(str, idx)), ', '.join(map(q, checks)), q(mode), q(version), marker, q(start), ', '.join(map(q, backup)), restore_part(a)))
    return out


def answers_part(s):
    """The "answers" of a guide step (questions asked after Done, or at once with "answersOnly"; docs/engine.md "Step
    contract") as the end of its $steps line, or '' when it has none. A bad list stops the build (the schema says the
    same: scripts/check_manifest.py)."""
    if 'answers' not in s:
        return ''
    qs = s['answers']
    def no(why):
        """Stop the build with the step name and the reason its answers are not valid."""
        raise SystemExit('step %r: answers: %s' % (s['name'], why))
    if s.get('kind', 'script') != 'guide':
        no('only a guide step (kind "guide") can ask questions')
    if not isinstance(qs, list) or not 1 <= len(qs) <= 4:
        no('1 to 4 questions, not %s' % (len(qs) if isinstance(qs, list) else type(qs).__name__))
    words, out = {}, []   # words: key -> the button words of each earlier yes/no or pick question
    for i, a in enumerate(qs, 1):
        if not isinstance(a, dict) or set(a) - {'key', 'prompt', 'kind', 'choices', 'failOn', 'showIf'}:
            no('question %d: only key, prompt, kind, choices, failOn and showIf' % i)
        key, prompt, kind, choices = a.get('key'), a.get('prompt'), a.get('kind'), a.get('choices')
        if not isinstance(key, str) or not re.fullmatch(r'[a-z][a-z0-9-]{0,23}', key):
            no('question %d: the key must be 1 to 24 lowercase letters, digits or "-", starting with a letter' % i)
        if key in words:
            no('question %d: the key %r is used twice' % (i, key))
        if not isinstance(prompt, str) or not 1 <= len(prompt) <= TEXT_LIMITS['answer prompt']:
            no('question %r: the prompt must have 1 to %d characters' % (key, TEXT_LIMITS['answer prompt']))
        if kind not in ('yesno', 'pick', 'text'):
            no('question %r: the kind must be yesno, pick or text' % key)
        if kind == 'pick':
            if not isinstance(choices, list) or not 2 <= len(choices) <= 4 or not all(isinstance(c, str) and 1 <= len(c) <= TEXT_LIMITS['answer choice'] for c in choices):
                no('question %r: a pick needs 2 to 4 choices of 1 to %d characters' % (key, TEXT_LIMITS['answer choice']))
            if len({c.strip().lower() for c in choices}) != len(choices):
                no('question %r: the choices of a pick must differ (case and spaces ignored)' % key)
        elif 'choices' in a:
            no('question %r: only a pick has choices' % key)
        mine = [] if kind == 'text' else ['Yes', 'No'] if kind == 'yesno' else [c.strip() for c in choices]
        fail, dep = a.get('failOn'), a.get('showIf')   # E2: the answers that mean the step failed; E3: the question shows only after these answers
        if 'failOn' in a and not (s.get('answersOnly') and mine and word_list(fail, mine)):
            no('question %r: failOn (only in a step with "answersOnly": true) names 1 or more answers of this yes/no or pick question, each one time' % key)
        dep_ok = isinstance(dep, dict) and set(dep) == {'key', 'in'} and isinstance(dep['key'], str) and word_list(dep['in'], words.get(dep['key'], []))
        if 'showIf' in a and not dep_ok:
            no('question %r: showIf needs "key" (an earlier yes/no or pick question of this step) and "in" (1 or more of its answers, each one time)' % key)
        more = ('; FailOn = @(%s)' % ', '.join(q(w.strip()) for w in fail)) if fail else ''
        more += ('; ShowKey = %s; ShowIn = @(%s)' % (q(dep['key']), ', '.join(q(w.strip()) for w in dep['in']))) if dep else ''
        words[key] = mine
        out.append('@{ Key = %s; Prompt = %s; Kind = %s; Choices = @(%s)%s }' % (q(key), q(prompt.strip()), q(kind), ', '.join(q(c.strip()) for c in choices or []), more))
    return '; Answers = @(%s)' % ', '.join(out)

def ascii_text(rel):
    """Return an app text file as ASCII text; stop the build with a plain message when it is not ASCII."""
    try:
        return (ROOT / rel).read_bytes().decode('ascii')
    except UnicodeDecodeError:
        raise SystemExit('cannot embed %s: non-ASCII text (keep sources ASCII)' % rel)

def use_shared(text, shared):
    """Return `text` with each shared block replaced by its one SHARED line; the build checks that the engine's rule
    (one line back to the block) gives the same text again."""
    def one(m):
        """Return the SHARED line for a block that is in `shared`, else the block itself."""
        key = '%s-%s' % (m.group(1), hashlib.sha256(m.group(0).encode()).hexdigest()[:8])
        return (SHARED_LINE % (key, m.group(1)) + '\n') if key in shared else m.group(0)
    out = SHARED_RE.sub(one, text)
    back = re.sub(r'^# @@SHARED (\S+)@@.*\n', lambda m: shared[m.group(1)], out, flags=re.M)
    assert back == text, 'a shared block does not round-trip'
    return out


def file_parts(b):
    """Return (the $shared lines, the $files lines with a banner each) for the bundle's files: text files as readable
    here-strings (shared blocks once), other files as base64."""
    texts = {f['src']: ascii_text(f['src']) for f in b['files'] if (ROOT / f['src']).suffix.lower() in TEXT}
    shared = shared_blocks(texts)
    lines = ["$shared[%s] = %s" % (q(k), here(v)) for k, v in sorted(shared.items())]
    parts = []
    for i, f in enumerate(b['files'], 1):
        src = ROOT / f['src']
        data = src.read_bytes()
        sha = hashlib.sha256(data).hexdigest()[:12]
        if f['src'] in texts:
            body, kind = here(use_shared(texts[f['src']], shared)), 'text'
        else:
            b64 = base64.b64encode(data).decode('ascii')
            body, kind = "@'\n" + '\n'.join(textwrap.wrap(b64, 100)) + "\n'@", 'base64'
        parts.append('# ---- File %d of %d: %s\\%s (from %s, sha256 %s)' % (i, len(b['files']), f['dir'], src.name, f['src'], sha))
        parts.append("$files += @{ Dir = %s; Name = %s; Kind = '%s'; Sha = '%s'; Data = %s }"
                     % (q(f['dir']), q(src.name), kind, sha, body))
    return lines, parts


def step_lines(b):
    """Return the $steps lines of the bundle, one per manifest step (kind "guide": a step the PFM does in another
    program, with guide lines, an address to open and a marker file on Done)."""
    steps = ['$steps += @{ Name = %s; Title = %s; Dir = %s; File = %s; Default = $%s; AskParam = %s; AskPrompt = %s; ScreenOnly = %s; Minutes = %d; Args = %s; '
             'Note = %s; Kind = %s; Guide = @(%s); Url = %s; UrlConfig = %s; Marker = %s; Estimate = %d; DoneText = %s; DoneLog = %s; Makes = @(%s); After = @(%s); Optional = $%s; Help = %s }'
             % (q(s['name']), q(s.get('title', '')), q(s['dir']), q(s['file']), 'true' if step_default(s) else 'false',
                q(s.get('ask', {}).get('param', '')), q(s.get('ask', {}).get('prompt', '')), q(s.get('screenOnly', '')),
                int(s.get('minutes', 30)), q(s.get('args', '')), q(s.get('note', '')), q(s.get('kind', 'script')),
                ', '.join(q(g) for g in s.get('guide', [])), q(s.get('url', '')), q(s.get('urlConfig', '')), q(s.get('marker', '')),
                int(s.get('estimate', 0)) * 60, q(s.get('doneText', '')), q(s.get('doneLog', '')),
                ', '.join('@{ kind = %s; name = %s }' % (q(m['kind']), q(m['name'])) for m in s.get('makes', [])), ', '.join(q(a) for a in s.get('after', [])),
                'true' if s.get('default', True) is False else 'false', q(s.get('help', '')))   # optional = "default": false only; a files-changed default is still a needed step
             for s in b['steps']]
    for s in b['steps']:
        assert s.get('url') or not s.get('urlConfig'), 'a step with "urlConfig" needs its own "url" (the host rule): %s' % s['name']
        assert (s.get('kind') == 'guide' and not s['file']) or any(f['dir'] == s['dir'] and Path(f['src']).name == s['file'] for f in b['files']), s
    doing = lambda s: ('; Doing = %s' % q(s['doing'].strip())) if s.get('doing') else ''   # L7: the now-doing sentence; a step without these fields: the line as before
    return [line[:-2] + doing(s) + hand_part(s) + answers_part(s) + ' }' for line, s in zip(steps, b['steps'])]


def fetch_lines(b):
    """Return the $fetch lines: data files the round downloads (not code, PFM 3A). Repo files come from raw main, or
    from the bundle's tagged "release" (a fixed address), checked by SHA-256; public pages come as they are."""
    fetch = []
    for f in b.get('fetch', []):
        if 'src' in f:
            data = (ROOT / f['src']).read_bytes()
            url = 'https://raw.githubusercontent.com/' + APP['repo'] + '/' + b.get('release', 'main') + '/' + f['src']
            fetch.append((f['dir'], Path(f['src']).name, url, hashlib.sha256(data).hexdigest()))
        else:
            fetch.append((f['dir'], f['name'], f['url'], ''))
    return ['$fetch += @{ Dir = %s; Name = %s; Url = %s; Sha = %s }' % tuple(q(x) for x in t) for t in fetch]


def engine_for_app(ui_text):
    """Put the shared UI file, the window layout values and the app's facts into the engine text. The build stops
    when a window value's placeholder is not in the engine exactly once.

    Args:
        ui_text: the text of engine/rade_ui.ps1 and engine/rade_ui_text.ps1, joined (it must hold no placeholder).

    Returns:
        The engine text for this application: the shared UI file in its slot, the values of engine/window.json and the
        app's facts (home page, file prefix, folder) in their placeholders.
    """
    assert '@@' not in ui_text, 'engine/rade_ui.ps1 must not hold a placeholder'
    rade_tokens.check_tokens(ui_text)
    assert ENGINE.count('    # @@UI@@') == 1, 'the UI slot (# @@UI@@) must be in the engine once'
    engine = ENGINE.replace('    # @@UI@@', '\n'.join(('    ' + x) if x else x for x in ui_text.rstrip('\n').split('\n')))
    in_ps = {k: v for k, v in site_values().items() if k != '@@RADE_REPO@@'}   # the repo goes only into the bundle header
    for src, values in (('engine/window.json', window_values()), ('apps.json', in_ps)):
        for k, v in values.items():
            if engine.count(k) != 1:   # a value nobody uses, or used twice, would be dropped or doubled without a word
                raise SystemExit('the engine must hold %s exactly once (%s)' % (k, src))
            engine = engine.replace(k, v)
    return engine.replace('@@HOME@@', APP['home']).replace('@@PREFIX@@', APP['prefix']).replace('@@APP@@', APP['folder'])


def app_logo_bytes():
    """Return the bytes of the application's logo: the PNG file that the manifest's application.logo names (a path in
    the application repo), or no bytes when it names none. The window shows it under the RADE logo once the user
    chooses the application (the Administrator, 2026-11-18). Stops the build when the path leaves the application repo
    (an absolute path, a '..' part, or a link that resolves outside), or when the file is missing or is not a PNG.

    Returns:
        The PNG bytes, or b'' when application.logo is not set.
    """
    rel = APP.get('logo')
    if not rel:
        return b''
    path = (ROOT / rel).resolve()
    if rel.startswith('/') or '..' in Path(rel).parts or not path.is_relative_to(ROOT):
        sys.exit('application.logo: the path must stay inside the application repo: ' + rel)
    if not path.is_file():
        sys.exit('application.logo: no file at ' + rel)
    data = path.read_bytes()
    if not data.startswith(b'\x89PNG\r\n\x1a\n'):
        sys.exit('application.logo: not a PNG file: ' + rel)
    return data


def bundle_body(b, ui_text):
    """Return the bundle text after its header: the settings, the shared blocks, the files, the steps and the other
    lists, the applications and the engine, each part after a banner line."""
    shared, files = file_parts(b)
    collect = ['$collect += @{ Dir = %s; Name = %s; Step = %s }' % (q(c['dir']), q(c['name']), q(c.get('step', ''))) for c in b['collect']]
    cleanup = ['$cleanup += @{ Path = %s; Kind = %s }' % (q(c['path']), q(c['kind'])) for c in b.get('cleanup', [])]
    # Support scripts that keep their names (they load each other) and samples: made by the app, so cleanup may recycle them.
    known = sorted({f.name for d, pat in APP['knownDirs'] for f in (ROOT / d).glob(pat)})
    logo = base64.b64encode(LOGO.read_bytes()).decode('ascii')   # the window's logo
    app_logo = base64.b64encode(app_logo_bytes()).decode('ascii')   # the application's logo under it ('' when none)
    go = q('https://raw.githubusercontent.com/' + APP['repo'] + '/main/go.md')
    rel = q('https://raw.githubusercontent.com/' + APP['repo'] + '/main/rade-release.json')
    parts = [
        ('Settings', ['$goUrl = %s' % go, '$releaseUrl = %s' % rel, "$webAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) RADE'",
                      "$logoPng = '%s'" % logo, '$scriptExts = @(' + ', '.join(q(x) for x in SCRIPT_EXTS) + ')', "$appLogoPng = '%s'" % app_logo, rade_tokens.font_lines(),
                      '$ownPatterns = @(' + ', '.join(q(p) for p in APP['own']) + ')', '$round = %s' % q(b['round']), '$appFolder = %s' % q(APP['folder']), "$usersRoot = 'C:\\Users'"]),
        ('Shared blocks (%d): each is written back into the files that name it' % len(shared), ['$shared = @{}'] + shared),
        ('Files written to this computer (%d)' % len(b['files']), ['$files = @()'] + files),
        ('Steps (%d), downloads, results to collect, clean-up' % len(b['steps']),
         ['$fetch = @()'] + fetch_lines(b) + ['$steps = @()'] + step_lines(b) + ['$collect = @()'] + collect + ['$cleanup = @()'] + cleanup),
        ('Applications', ['$known = @(%s)' % ', '.join(q(k) for k in known), '$apps = @()'] + app_lines(b)),
    ]
    text = ''.join('# ==== Part %d of %d: %s\n%s\n' % (i, len(parts) + 1, title, '\n'.join(lines)) for i, (title, lines) in enumerate(parts, 1))
    return text + '# ==== Part %d of %d: the RADE engine (engine/ps, in run order)' % (len(parts) + 1, len(parts) + 1) + engine_for_app(ui_text)


def contents(head, body):
    """Return the "Contents" comment: every banner line of the body with the line number it has in the whole bundle."""
    marks, inside = [], False   # inside: a line of a here-string (a file's own text), never a banner
    for n, line in enumerate(body.split('\n'), 1):
        if inside:
            inside = not line.startswith("'@")
        elif BANNER.match(line):
            marks.append((n, line.strip()[7:]))
        elif line.endswith("@'"):
            inside = True
    first = head.count('\n') + len(marks) + 3   # the bundle line of body line 1: after the hash line, the header and this list
    rows = ['#   line %5d  %s' % (first + n - 1, (('  ' if line.startswith('File') else '') + line)[:150]) for n, line in marks]
    return '# ==== Contents (GENERATED; the line numbers are lines of this bundle)\n' + '\n'.join(rows) + '\n'


def build(b):
    """Return the whole bundle text for one manifest bundle: the hash line (engine/rade_hash.py), the header (what it is, how to
    run it, its sources), the contents list and the body, in the paste guard (engine/rade_hash.py GUARD_START, GUARD_END). The build id is the first 8 hex of the body's SHA-256."""
    bad = collect_problems(b)
    if bad:
        sys.exit('\n'.join(bad))
    ui_text = ''.join(f.read_text(encoding='ascii') for f in UI_FILES)   # part 2 right after part 1
    body = bundle_body(b, ui_text)
    build_id = hashlib.sha256(body.encode('ascii')).hexdigest()[:8]
    modes = {a.get('mode', 'test') for a in b.get('apps', [])} or {'test'}
    sends = (' on this computer. It sends nothing.' if modes == {'deploy'} else ', then opens an Outlook draft with them (never sent; a deploy makes no draft).'
             if 'deploy' in modes else ', then opens an Outlook draft with them (never sent).')
    head = ('<#\n%s'
            '  RADE, round bundle: %s.\n'
            '  GENERATED by the RADE engine (%s engine/rade_build.py, sha256 %s; engine/rade_ui.ps1, sha256 %s; engine/rade_ui_text.ps1, sha256 %s) from %s; do not edit.\n'
            '%s'
            '  What it does: it uses your Windows profile folder. It writes the files below into the task folders under\n'
            '  C:\\Users\\<DODID>\\OneDrive - United States Air Force\\RADE\\%s (replacing older copies), runs the steps,\n'
            '  and saves its results in Rounds\\%s%s No download, no admin rights.\n'
            '  To read it: the Contents list below gives the line of each part and file; each part starts with a "# ====" line.\n'
            '#>\n%s$buildId = \'%s\'\n$engineRelease = %d\n' % (run_steps(), b['title'], site_values()['@@RADE_REPO@@'], file_sha('engine/rade_build.py'), file_sha('engine/rade_ui.ps1'),
                file_sha('engine/rade_ui_text.ps1'), MANIFEST, part_lines(), APP['folder'], b['round'], sends, rade_hash.GUARD_START, build_id, ENGINE_RELEASE))
    return rade_hash.add_line(head + contents(head, body) + body.rstrip('\n') + '\n' + rade_hash.GUARD_END)   # GUARD_START is in head


# Text lengths (the Administrator, 2026-11-15; docs/window-design.md "Text lengths"). The most characters of each text an
# application gives the window, set from the real font (Segoe UI, measured in the window by the Windows job) and the
# narrowest card (604 px: 1280 x 800 at 150 % scaling). The window never cuts a part off: a longer text wraps or ends
# with "..." as the table in the document says. In this release a longer text is a WARNING line of the build, not a
# failure; a later release makes it a failure. This table is the one source: tests/engine_test.sh checks that the
# document has the same numbers.
TEXT_LIMITS = {'application name': 48, 'version': 14, 'summary': 150, 'step name': 56, 'step note': 200,
               'step title': 56, 'guide line': 100, 'guide lines': 10, 'doneText': 24, 'step doing': 80, 'step help': 160, 'answer prompt': 120, 'answer choice': 33}


def text_lengths(b):
    """One WARNING line for each text of a bundle that is longer than its limit."""
    found = []
    def over(what, field, value):
        """Add a WARNING line to `found` when `value` is longer than the limit of `field`."""
        if isinstance(value, str) and len(value) > TEXT_LIMITS[field]:
            found.append('WARNING text length: %s: %s has %d characters, the limit is %d (docs/window-design.md "Text lengths")'
                         % (what, field, len(value), TEXT_LIMITS[field]))
    if not b.get('apps') and APP:
        over('application %r' % str(APP.get('name', ''))[:40], 'application name', APP.get('name'))
    for app in b.get('apps', []):
        what = 'application %r' % app.get('name', '')[:40]
        over(what, 'application name', app.get('name'))
        over(what, 'version', app.get('version'))
        over(what, 'summary', app.get('summary'))
    for st in b.get('steps', []):
        what = 'step %r' % st.get('name', '')[:40]
        over(what, 'step name', st.get('name'))
        over(what, 'step title', st.get('title'))
        over(what, 'step note', st.get('note'))
        over(what, 'doneText', st.get('doneText'))
        over(what, 'step doing', st.get('doing'))
        over(what, 'step help', st.get('help'))
        for g in st.get('guide', []):
            over(what, 'guide line', g)
        numbered = [g for g in st.get('guide', []) if isinstance(g, str) and re.match(r'\d+\.\s+\S', g)]
        if len(numbered) > TEXT_LIMITS['guide lines']:   # a count, not a length: more than the limit of numbered lines
            found.append('WARNING text length: %s: guide has %d numbered lines, the limit is %d (docs/window-design.md "Text lengths")'
                         % (what, len(numbered), TEXT_LIMITS['guide lines']))
    return found


def main():
    """Read the arguments and the app's manifest, then build (or, with --check, compare) every bundle it names."""
    global ROOT, APP, MANIFEST
    import argparse
    ap = argparse.ArgumentParser(description='Build RADE round bundles for one application.')
    ap.add_argument('--app-root', help='the application repo root')
    ap.add_argument('--manifest', default='scripts/paste_bundles.json', help='manifest path inside the app repo')
    ap.add_argument('--check', action='store_true', help='exit 1 if a bundle is out of date')
    ap.add_argument('--sha', action='store_true', help="print the engine's sha256 (every engine file) and exit")
    a = ap.parse_args()
    if a.sha:
        print(ENGINE_SHA); return
    if not a.app_root:
        ap.error('--app-root is required')
    ROOT, MANIFEST = Path(a.app_root).resolve(), a.manifest
    m = json.loads((ROOT / MANIFEST).read_text())
    APP = m['application']
    stale = 0
    for b in m['bundles']:   # every bundle path is checked before the first file is written
        rade_hash.text_copy(ROOT / b['out'])
    for b in m['bundles']:
        out = ROOT / b['out']
        text = build(b)
        if a.check:
            stale += rade_hash.stale(out, text, ENGINE_RELEASE, b['out'])   # prints STALE: the bundle, its .txt copy or its stored hash file is old
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        print('BUILT %s bytes=%d files=%d steps=%d' % (b['out'], len(text), len(b['files']), len(b['steps'])))
        print(rade_hash.write(out, text, ENGINE_RELEASE))   # writes the bundle, its .txt copy and its stored hash file; gives the HASH line
        for line in text_lengths(b):
            print(line)
    if a.check:
        print('PASTE bundles=%d stale=%d' % (len(m['bundles']), stale))
        sys.exit(1 if stale else 0)


# The engine's hash: every file of the engine (docs/engine.md "How an app gets the engine"): this file, each engine/ps
# part in build order, the shared UI file, the window layout values and the logo (path, then bytes). An app's lock still checks each file on its
# own, and a bundle's header names each file with its own hash (part_lines); this one value is what --sha prints.
ENGINE_SHA = hashlib.sha256(b''.join(rel.encode() + b'\0' + (ENGINE_ROOT / rel).read_bytes() + b'\0' for rel in
                                     ['engine/rade_build.py', 'engine/rade_hash.py', 'engine/rade_fields.py', 'engine/rade_parts.py'] + ['engine/ps/' + x for x in ENGINE_PARTS + WINDOW_PARTS]
                                     + ['engine/rade_ui.ps1', 'engine/rade_ui_text.ps1', 'engine/window.json', 'apps.json', logo_path()] + rade_tokens.FILES)).hexdigest()
# The number of the next engine release (tag engine-v<N>); raise it before each release (docs/engine.md "Releases").
# The saved runner copy is replaced only by a bundle with a higher number (the Administrator, 2026-11-17).
ENGINE_RELEASE = 40
APP, MANIFEST = None, None

if __name__ == '__main__':
    main()
