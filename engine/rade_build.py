#!/usr/bin/env python3
"""RADE engine: build an application's round bundles from its RADE manifest (schemas/rade-manifest.schema.json).

Moved from rhope-ops/90-161.Z scripts/build_paste_bundles.py (the Administrator, 2026-11-14: start using this repo).
App facts (name, folder, file prefix, home page, own file patterns, repo) come from the manifest "application" block;
RADE's own logo comes from this repo (assets/logo/logo-rho-128.png: Rho Bold, from engine-v10). The history notes below name 90-161.Z, the first app.

A bundle is one PowerShell text (RADE, the Redacted Application Deployment Engine, PFM 14 Nov 26; formerly the
"90-161.Z Deployer" and the "runner") (Windows PowerShell 5.1) that the PFM copies from its raw page, pastes into
Windows PowerShell ISE and runs with F5. It is a
bootstrapper for fast test rounds (PFM 1A, 6A: function over form):
  1. uses the Windows profile folder as the DODID (no question: PFM 13 Nov, the empty-box default worked) and shows
     the real path on screen (reports and e-mails still mask it);
  1b. recycles finished files (cleanup list in the JSON; only files 90-161.Z made; to the Recycle Bin) and reports
     what it recycled and what is left (folder counts, no file names) in the summary (R06, PFM 13 Nov);
  1c. RADE folder (PFM 14 Nov 26, R17): the app folder is OneDrive\\RADE\\90-161.Z; RADE\\Config holds the engine's own
     settings (rade-mail-to.txt, rade-checks.json); the app's Config stays in 90-161.Z\\Config. On Run, an old
     OneDrive\\90-161.Z folder is moved into RADE as one folder move (if the move fails, the round uses the old folder);
  1d. saved checks (PFM 14 Nov 26): a PASSED check is kept in RADE\\Config\\rade-checks.json for 7 days and is not run
     again (other apps can read the file; its "about" field says how); a new PowerShell or PnP version, another site,
     an older result or "Run checks again" runs it again; a check that did not pass always runs again;
  2. makes each task folder under C:\\Users\\<DODID>\\OneDrive - United States Air Force\\RADE\\90-161.Z if missing and
     writes every file (text: same content as UTF-8 with BOM and CRLF; binary: byte-exact from base64);
  3. runs the steps one by one (each a runner file, as a child powershell.exe with -Id and -NoPause), with a live
     log, DODID masked, and PASS/FAIL counts per step. A step of kind "guide" (R13, PFM 14 Nov 26: RADE
     delivers every file, no separate downloads) is work the PFM does in another program, such as a flow import:
     RADE writes its file, opens the address, puts the file path on the clipboard and waits for Done or Skip.
     Log text (R13, PFM 14 Nov 26): one heading per step ("Step k of n: name"), the step's output indented under it,
     one result line (PASSED, NEEDS REVIEW or SKIPPED); the e-mail subject ends in PASSED or NEEDS REVIEW;
  4. writes a results folder Rounds\\<round> with one report file (summary + full masked log) and copies of the
     collect files (PDFs), ready to attach to one e-mail (no zip: zips do not cross the boundary, PFM 13 Nov);
  5. makes an Outlook draft (classic Outlook, COM): subject = summary line 1, body = the rest, every results file
     attached, never sent (R05); To from the window box, saved in RADE\\Config\\rade-mail-to.txt (R06, R17). If no draft can be made, it opens the results folder and puts
     the summary on the clipboard instead (R04 behavior).
The window (the Administrator, 2026-11-14, "One thing"; docs/window-design.md) shows one statement or one question at a
time: the application, a check that failed or needs you, the plan, the run, a step you do by hand, the result. All
checks, the step boxes, the files, the made list and the log are in the Record (F2). The Local checks run when the window
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
  --check: exit 1 if a bundle is out of date. --sha: print the engine's sha256 (this file and engine/ps, see ENGINE_SHA).
"""
import base64, hashlib, json, re, sys, textwrap
from pathlib import Path

ENGINE_ROOT = Path(__file__).resolve().parent.parent
LOGO = ENGINE_ROOT / 'assets/logo/logo-rho-128.png'   # RADE's own logo (top left of the window)
UI_FILE = ENGINE_ROOT / 'engine/rade_ui.ps1'   # the shared UI file: theme tokens, builders and the layout self-check (R28; docs/engine.md "How an app gets the engine")
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
    h = hashlib.sha256()
    for rel in sorted(paths):
        h.update(rel.encode() + b'\0' + (ROOT / rel).read_bytes() + b'\0')
    return h.hexdigest()[:16]

def here(text):
    text = text.replace('\r\n', '\n')
    if text.endswith('\n'):
        text = text[:-1]
    for line in text.split('\n'):
        if line.startswith("'@"):
            raise SystemExit("cannot embed: a line starts with '@")
    if any(ord(c) > 127 for c in text):
        raise SystemExit('cannot embed: non-ASCII text (keep sources ASCII)')
    return "@'\n" + text + "\n'@"


def q(s):
    return "'" + s.replace("'", "''") + "'"


# ---- The engine's PowerShell (the Administrator, 2026-11-17: docs/code-standard.md C10). It lives in engine/ps as
# files that a person, the PowerShell parser and tests/check_code_standard.py can read one by one; this build joins them
# in run order into the text every bundle carries. Each part is a whole file that parses alone. The window parts are
# kept 4 spaces less indented than in the bundle and go where engine/ps/10-window.ps1 has its "# @@WINDOW@@" line.
ENGINE_DIR = ENGINE_ROOT / 'engine/ps'
ENGINE_PARTS = ['01-base.ps1', '02-config.ps1', '03-files.ps1', '04-steps.ps1', '05-installed.ps1', '06-round.ps1',
                '07-checks.ps1', '08-saved-checks.ps1', '09-start.ps1', '10-window.ps1', '11-text-mode.ps1']
WINDOW_PARTS = ['window/01-setup.ps1', 'window/02-fixed-parts.ps1', 'window/03-card.ps1', 'window/04-record-parts.ps1',
                'window/05-alignment.ps1', 'window/06-open.ps1', 'window/07-run.ps1', 'window/08-hand-step.ps1',
                'window/09-record.ps1', 'window/10-keys.ps1']
WINDOW_SLOT = '    # @@WINDOW@@\n'


def indent(text, pad):
    """Return `text` with `pad` put before each line that is not empty."""
    return ''.join((pad + x) if x.strip('\n') else x for x in text.splitlines(keepends=True))


def engine_text():
    """Return the engine's PowerShell: the parts of ENGINE_PARTS in order, with the window parts (indented 4 spaces)
    in the slot of 10-window.ps1. The text starts with a newline, as the bundle layout expects."""
    read = lambda rel: (ENGINE_DIR / rel).read_text(encoding='ascii')
    window = ''.join(indent(read(w), '    ') for w in WINDOW_PARTS)
    text = ''.join(read(p).replace(WINDOW_SLOT, window) for p in ENGINE_PARTS)
    return '\n' + text


ENGINE = engine_text()

# Checks every application runs (the rest come from its steps' "needs"). Ids must exist in the engine's $checkDefs.
BASE_CHECKS = ['nipr', 'ps', 'lang', 'onedrive', 'disk', 'write', 'child', 'outlook', 'net-bookmark']
CHECK_IDS = re.findall(r"@\{ Id = '([a-z-]+)'", ENGINE)


START_RE = re.compile(r'[A-Za-z0-9][A-Za-z0-9 ._-]*(/[A-Za-z0-9][A-Za-z0-9 ._-]*)*\.ps1')   # schemas/rade-manifest.schema.json app.start says the same


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
        # "marker": the app's install record on the site (one row of its own list). Plain names only: they go into a
        # command line and a CAML query. It needs the sign-in check, which reads it.
        mk = a.get('marker')
        marker = '$null'
        if mk:
            assert re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9 ]*', mk['list']) and re.fullmatch(r'[A-Za-z0-9]+', mk['key']) and re.fullmatch(r'[A-Za-z0-9_]+', mk['field']), 'app %r: marker list, key and field hold letters and digits only' % a['name']
            assert mode == 'deploy' and 'site-rights' in need, 'app %r: a marker needs mode deploy and a step that needs site-rights' % a['name']
            marker = '@{ List = %s; Key = %s; Field = %s }' % (q(mk['list']), q(mk['key']), q(mk['field']))
        # "start" (R28): the app's start script, a path inside its local install folder (OneDrive\\RADE\\<folder>). RADE's Start button runs
        # it in its own powershell.exe process after the checks pass; nothing is downloaded. Plain relative .ps1 paths only.
        start = a.get('start', '')
        assert not start or START_RE.fullmatch(start), 'app %r: start must be a relative .ps1 path of plain names (letters, digits, space, ".", "_", "-"), for example App/Start-App.ps1' % a['name']
        out.append('$apps += @{ Name = %s; Summary = %s; Steps = @(%s); Checks = @(%s); Mode = %s; Version = %s; Marker = %s; Start = %s }'
                   % (q(a['name']), q(a['summary']), ', '.join(str(i) for i in idx), ', '.join(q(c) for c in checks), q(mode), q(version), marker, q(start)))
    return out


ANSWER_KINDS = ('yesno', 'pick', 'text')


def answers_part(s):
    """The "answers" of a guide step (questions asked after Done; docs/engine.md "Step contract") as the end of its
    $steps line, or '' when it has none. A bad list stops the build (the schema says the same: scripts/check_manifest.py)."""
    if 'answers' not in s:
        return ''
    qs = s['answers']
    def no(why):
        raise SystemExit('step %r: answers: %s' % (s['name'], why))
    if s.get('kind', 'script') != 'guide':
        no('only a guide step (kind "guide") can ask questions')
    if not isinstance(qs, list) or not 1 <= len(qs) <= 4:
        no('1 to 4 questions, not %s' % (len(qs) if isinstance(qs, list) else type(qs).__name__))
    keys, out = set(), []
    for i, a in enumerate(qs, 1):
        if not isinstance(a, dict) or set(a) - {'key', 'prompt', 'kind', 'choices'}:
            no('question %d: only key, prompt, kind and choices' % i)
        key, prompt, kind, choices = a.get('key'), a.get('prompt'), a.get('kind'), a.get('choices')
        if not isinstance(key, str) or not re.fullmatch(r'[a-z][a-z0-9-]{0,23}', key):
            no('question %d: the key must be 1 to 24 lowercase letters, digits or "-", starting with a letter' % i)
        if key in keys:
            no('question %d: the key %r is used twice' % (i, key))
        keys.add(key)
        if not isinstance(prompt, str) or not 1 <= len(prompt) <= TEXT_LIMITS['answer prompt']:
            no('question %r: the prompt must have 1 to %d characters' % (key, TEXT_LIMITS['answer prompt']))
        if kind not in ANSWER_KINDS:
            no('question %r: the kind must be yesno, pick or text' % key)
        if kind == 'pick':
            if not isinstance(choices, list) or not 2 <= len(choices) <= 4 or not all(isinstance(c, str) and 1 <= len(c) <= TEXT_LIMITS['answer choice'] for c in choices):
                no('question %r: a pick needs 2 to 4 choices of 1 to %d characters' % (key, TEXT_LIMITS['answer choice']))
            if len({c.strip().lower() for c in choices}) != len(choices):
                no('question %r: the choices of a pick must differ (case and spaces ignored)' % key)
        elif 'choices' in a:
            no('question %r: only a pick has choices' % key)
        out.append('@{ Key = %s; Prompt = %s; Kind = %s; Choices = @(%s) }' % (q(key), q(prompt.strip()), q(kind), ', '.join(q(c.strip()) for c in choices or [])))
    return '; Answers = @(%s)' % ', '.join(out)


def build(b):
    parts = []
    for f in b['files']:
        src = ROOT / f['src']
        data = src.read_bytes()
        sha = hashlib.sha256(data).hexdigest()[:12]
        if src.suffix.lower() in TEXT:
            body, kind = here(data.decode('ascii')), 'text'
        else:
            b64 = base64.b64encode(data).decode('ascii')
            body, kind = "@'\n" + '\n'.join(textwrap.wrap(b64, 100)) + "\n'@", 'base64'
        parts.append("$files += @{ Dir = %s; Name = %s; Kind = '%s'; Sha = '%s'; Data = %s }"
                     % (q(f['dir']), q(src.name), kind, sha, body))
    # kind "guide": a step the PFM does in another program (guide lines, an address to open, a marker file on Done).
    steps = ['$steps += @{ Name = %s; Title = %s; Dir = %s; File = %s; Default = $%s; AskParam = %s; AskPrompt = %s; ScreenOnly = %s; Minutes = %d; Args = %s; Note = %s; Kind = %s; Guide = @(%s); Url = %s; UrlConfig = %s; Marker = %s; Estimate = %d; DoneText = %s; DoneLog = %s; Makes = @(%s); After = @(%s); Optional = $%s; Help = %s }'
             % (q(s['name']), q(s.get('title', '')), q(s['dir']), q(s['file']), 'true' if step_default(s) else 'false',
                q(s.get('ask', {}).get('param', '')), q(s.get('ask', {}).get('prompt', '')), q(s.get('screenOnly', '')),
                int(s.get('minutes', 30)), q(s.get('args', '')), q(s.get('note', '')), q(s.get('kind', 'script')),
                ', '.join(q(g) for g in s.get('guide', [])), q(s.get('url', '')), q(s.get('urlConfig', '')), q(s.get('marker', '')),
                int(s.get('estimate', 0)) * 60, q(s.get('doneText', '')), q(s.get('doneLog', '')),
                ', '.join('@{ kind = %s; name = %s }' % (q(m['kind']), q(m['name'])) for m in s.get('makes', [])), ', '.join(q(a) for a in s.get('after', [])),
                'true' if s.get('default', True) is False else 'false', q(s.get('help', '')))   # optional = "default": false only; a files-changed default is still a needed step
             for s in b['steps']]
    steps = [line[:-2] + answers_part(s) + ' }' for line, s in zip(steps, b['steps'])]   # a step without "answers": the line as before
    apps = app_lines(b)
    # Data files the round downloads (not code, PFM 3A): repo files from raw main, checked by SHA-256; public pages as they are.
    fetch = []
    for f in b.get('fetch', []):
        if 'src' in f:
            data = (ROOT / f['src']).read_bytes()
            # A tagged release (bundle "release") gives a fixed address; without it the file comes from main.
            url = 'https://raw.githubusercontent.com/' + APP['repo'] + '/' + b.get('release', 'main') + '/' + f['src']
            fetch.append((f['dir'], Path(f['src']).name, url, hashlib.sha256(data).hexdigest()))
        else:
            fetch.append((f['dir'], f['name'], f['url'], ''))
    fetchs = ['$fetch += @{ Dir = %s; Name = %s; Url = %s; Sha = %s }' % tuple(q(x) for x in t) for t in fetch]
    for s in b['steps']:
        assert (s.get('kind') == 'guide' and not s['file']) or any(f['dir'] == s['dir'] and Path(f['src']).name == s['file'] for f in b['files']), s
    collect = ['$collect += @{ Dir = %s; Name = %s; Step = %s }' % (q(c['dir']), q(c['name']), q(c.get('step', ''))) for c in b['collect']]
    cleanup = ['$cleanup += @{ Path = %s; Kind = %s }' % (q(c['path']), q(c['kind'])) for c in b.get('cleanup', [])]
    # Support scripts that keep their names (they load each other) and samples: made by 90-161.Z, so cleanup may recycle them.
    known = sorted({f.name for d, pat in APP['knownDirs'] for f in (ROOT / d).glob(pat)})
    logo = base64.b64encode(LOGO.read_bytes()).decode('ascii')   # the window's logo
    ui_text = UI_FILE.read_text(encoding='ascii')
    assert '@@' not in ui_text, 'engine/rade_ui.ps1 must not hold a placeholder'
    engine = ENGINE.replace('    # @@UI@@', '\n'.join(('    ' + x) if x else x for x in ui_text.rstrip('\n').split('\n')))
    engine = engine.replace('@@HOME@@', APP['home']).replace('@@PREFIX@@', APP['prefix']).replace('@@APP@@', APP['folder'])
    own = '$ownPatterns = @(' + ', '.join(q(p) for p in APP['own']) + ')\n'
    go = q('https://raw.githubusercontent.com/' + APP['repo'] + '/main/go.md')
    rel = q('https://raw.githubusercontent.com/' + APP['repo'] + '/main/rade-release.json')
    body = ('$goUrl = %s\n$releaseUrl = %s\n$webAgent = \'Mozilla/5.0 (Windows NT 10.0; Win64; x64) RADE\'\n$logoPng = \'%s\'\n%s$round = %s\n$appFolder = %s\n$usersRoot = \'C:\\Users\'\n$files = @()\n%s\n$fetch = @()\n%s\n$steps = @()\n%s\n$collect = @()\n%s\n$cleanup = @()\n%s\n$known = @(%s)\n$apps = @()\n%s\n%s'
            % (go, rel, logo, own, q(b['round']), q(APP['folder']), '\n'.join(parts), '\n'.join(fetchs), '\n'.join(steps), '\n'.join(collect), '\n'.join(cleanup), ', '.join(q(k) for k in known), '\n'.join(apps), engine))
    build_id = hashlib.sha256(body.encode('ascii')).hexdigest()[:8]
    modes = {a.get('mode', 'test') for a in b.get('apps', [])} or {'test'}
    sends = ' on this computer. It sends nothing.' if modes == {'deploy'} else ', then opens an Outlook draft with them (never sent; a deploy makes no draft).' if 'deploy' in modes else ', then opens an Outlook draft with them (never sent).'
    head = ('<#\n  RADE, round bundle: %s.\n'
            '  GENERATED by the RADE engine (rhope-ops/RADE engine/rade_build.py with engine/ps, sha256 %s; engine/rade_ui.ps1, sha256 %s) from %s; do not edit.\n'
            '  How to run: open Windows PowerShell ISE, File > New, paste all of this text into the script pane, press F5.\n'
            '  The RADE window opens: press Enter (or Run); it uses your Windows profile folder. It writes the files below into the task folders under\n'
            '  C:\\Users\\<DODID>\\OneDrive - United States Air Force\\RADE\\%s (replacing older copies), runs the steps,\n'
            '  and saves its results in Rounds\\%s%s No download, no admin rights.\n'
            '#>\n$buildId = \'%s\'\n$engineRelease = %d\n' % (b['title'], ENGINE_SHA[:12], hashlib.sha256(ui_text.encode('ascii')).hexdigest()[:12], MANIFEST, APP['folder'], b['round'], sends, build_id, ENGINE_RELEASE))
    return head + body


# Text lengths (the Administrator, 2026-11-15; docs/window-design.md "Text lengths"). The most characters of each text an
# application gives the window, set from the real font (Segoe UI, measured in the window by the Windows job) and the
# narrowest card (604 px: 1280 x 800 at 150 % scaling). The window never cuts a part off: a longer text wraps or ends
# with "..." as the table in the document says. In this release a longer text is a WARNING line of the build, not a
# failure; a later release makes it a failure. This table is the one source: tests/engine_test.sh checks that the
# document has the same numbers.
TEXT_LIMITS = {'application name': 48, 'version': 14, 'summary': 150, 'step name': 56, 'step note': 200,
               'step title': 56, 'guide line': 100, 'guide lines': 10, 'doneText': 24, 'step help': 160, 'answer prompt': 120, 'answer choice': 40}


def text_lengths(b):
    """One WARNING line for each text of a bundle that is longer than its limit."""
    found = []
    def over(what, field, value):
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
        over(what, 'step help', st.get('help'))
        for g in st.get('guide', []):
            over(what, 'guide line', g)
        numbered = [g for g in st.get('guide', []) if isinstance(g, str) and re.match(r'\d+\.\s+\S', g)]
        if len(numbered) > TEXT_LIMITS['guide lines']:   # a count, not a length: more than the limit of numbered lines
            found.append('WARNING text length: %s: guide has %d numbered lines, the limit is %d (docs/window-design.md "Text lengths")'
                         % (what, len(numbered), TEXT_LIMITS['guide lines']))
    return found


def main():
    global ROOT, APP, MANIFEST
    import argparse
    ap = argparse.ArgumentParser(description='Build RADE round bundles for one application.')
    ap.add_argument('--app-root', help='the application repo root')
    ap.add_argument('--manifest', default='scripts/paste_bundles.json', help='manifest path inside the app repo')
    ap.add_argument('--check', action='store_true', help='exit 1 if a bundle is out of date')
    ap.add_argument('--sha', action='store_true', help="print the engine's sha256 (this file and engine/ps) and exit")
    a = ap.parse_args()
    if a.sha:
        print(ENGINE_SHA); return
    if not a.app_root:
        ap.error('--app-root is required')
    ROOT, MANIFEST = Path(a.app_root).resolve(), a.manifest
    m = json.loads((ROOT / MANIFEST).read_text())
    APP = m['application']
    stale = 0
    for b in m['bundles']:
        out = ROOT / b['out']
        text = build(b)
        if a.check:
            if not out.exists() or out.read_bytes() != text.encode('ascii'):
                print('STALE ' + b['out']); stale += 1
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(text.encode('ascii'))
        print('BUILT %s bytes=%d files=%d steps=%d' % (b['out'], len(text), len(b['files']), len(b['steps'])))
        for line in text_lengths(b):
            print(line)
    if a.check:
        print('PASTE bundles=%d stale=%d' % (len(m['bundles']), stale))
        sys.exit(1 if stale else 0)


# The engine's hash: this file and each engine/ps part, in build order (path, then bytes). An app's lock still checks each
# file on its own (docs/engine.md "How an app gets the engine"); this one value names the engine in a bundle's header.
ENGINE_SHA = hashlib.sha256(b''.join(rel.encode() + b'\0' + (ENGINE_ROOT / rel).read_bytes() + b'\0' for rel in
                                     ['engine/rade_build.py'] + ['engine/ps/' + x for x in ENGINE_PARTS + WINDOW_PARTS])).hexdigest()
# The number of the next engine release (tag engine-v<N>); raise it before each release (docs/engine.md "Releases").
# The saved runner copy is replaced only by a bundle with a higher number (the Administrator, 2026-11-17).
ENGINE_RELEASE = 10
APP, MANIFEST = None, None

if __name__ == '__main__':
    main()
