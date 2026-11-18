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
  --check: exit 1 if a bundle is out of date. --sha: print the engine's sha256 (every engine file, see ENGINE_SHA).
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


def q(s):
    """Return `s` as a PowerShell single-quoted string ('' for each quote inside)."""
    return "'" + s.replace("'", "''") + "'"


# ---- The engine's PowerShell (the Administrator, 2026-11-17: docs/code-standard.md C10). It lives in engine/ps as
# files that a person, the PowerShell parser and scripts/code_standard.py can read one by one; this build joins them
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


def file_sha(rel):
    """Return the first 12 hex of the SHA-256 of one engine file (`rel` under the RADE root): the hash an app's lock
    holds for it, so a reader (and the app's own test) can match each part of a bundle to its locked file."""
    return hashlib.sha256((ENGINE_ROOT / rel).read_bytes()).hexdigest()[:12]


def engine_text():
    """Join the engine's PowerShell parts. The build stops when engine/ps and the part lists differ, or when the
    window slot is not there exactly once (a part or a slot would else be left out without a word).

    Returns:
        The parts of ENGINE_PARTS in order, with the window parts (indented 4 spaces) in the slot of 10-window.ps1.
        The text starts with a newline, as the bundle layout expects.
    """
    read = lambda rel: (ENGINE_DIR / rel).read_text(encoding='ascii')
    on_disk = sorted(p.relative_to(ENGINE_DIR).as_posix() for p in ENGINE_DIR.rglob('*.ps1'))
    assert on_disk == sorted(ENGINE_PARTS + WINDOW_PARTS), 'engine/ps and the part lists differ: %s' % sorted(
        set(on_disk) ^ set(ENGINE_PARTS + WINDOW_PARTS))   # a part nobody listed would be left out without a word
    assert sum(read(p).count(WINDOW_SLOT) for p in ENGINE_PARTS) == 1, 'the window slot (# @@WINDOW@@) must be there once'
    banner = lambda rel: '# ==== Engine part: engine/ps/%s (sha256 %s)\n' % (rel, file_sha('engine/ps/' + rel))   # in the Contents
    window = ''.join(indent(banner(w) + read(w), '    ') for w in WINDOW_PARTS)
    text = ''.join(banner(p) + read(p).replace(WINDOW_SLOT, window) for p in ENGINE_PARTS)
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
        """Stop the build with the step name and the reason its answers are not valid."""
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


# ---- Bundle layout (the Administrator, 2026-11-17: docs/code-standard.md C5, C6). A bundle is read by a person before it
# runs, so it starts with a list of its parts and their line numbers, and each part and each file has a banner line.
BANNER = re.compile(r'^\s*# (==== |---- File )')
# A block between "# >>> <name>: generated from ..." and "# <<< <name>" that two or more text files hold (a shared
# source copied into each script that must run alone) is kept once, in $shared, and each file holds one line in its
# place; the engine puts the block back when it writes the file (Write-BundleFile), so every file is the same as before.
SHARED_RE = re.compile(r'^# >>> ([\w-]+): generated from .*?\n# <<< \1\n', re.M | re.S)
SHARED_LINE = '# @@SHARED %s@@ (RADE writes the shared block "%s" here; its text is in the bundle part "Shared blocks")'


def ascii_text(rel):
    """Return an app text file as ASCII text; stop the build with a plain message when it is not ASCII."""
    try:
        return (ROOT / rel).read_bytes().decode('ascii')
    except UnicodeDecodeError:
        raise SystemExit('cannot embed %s: non-ASCII text (keep sources ASCII)' % rel)


def shared_blocks(texts):
    """Find the marked blocks that two or more of the text files hold. Takes {source path: text}; returns
    {key: block text}, where key = the block name and the first 8 hex of its SHA-256 (two versions get two keys)."""
    seen = {}
    for text in texts.values():
        for m in SHARED_RE.finditer(text):
            key = '%s-%s' % (m.group(1), hashlib.sha256(m.group(0).encode()).hexdigest()[:8])
            seen.setdefault(key, [m.group(0), 0])[1] += 1
    return {k: v[0] for k, v in seen.items() if v[1] > 1}


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
    steps = ['$steps += @{ Name = %s; Title = %s; Dir = %s; File = %s; Default = $%s; AskParam = %s; AskPrompt = %s; ScreenOnly = %s; Minutes = %d; Args = %s; Note = %s; Kind = %s; Guide = @(%s); Url = %s; UrlConfig = %s; Marker = %s; Estimate = %d; DoneText = %s; DoneLog = %s; Makes = @(%s); After = @(%s); Optional = $%s; Help = %s }'
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
    return [line[:-2] + answers_part(s) + ' }' for line, s in zip(steps, b['steps'])]   # a step without "answers": the line as before


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
    """Return the engine text for this application: the shared UI file in its slot and the app's facts (home page,
    file prefix, folder) in their placeholders."""
    assert '@@' not in ui_text, 'engine/rade_ui.ps1 must not hold a placeholder'
    assert ENGINE.count('    # @@UI@@') == 1, 'the UI slot (# @@UI@@) must be in the engine once'
    engine = ENGINE.replace('    # @@UI@@', '\n'.join(('    ' + x) if x else x for x in ui_text.rstrip('\n').split('\n')))
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
                      "$logoPng = '%s'" % logo, "$appLogoPng = '%s'" % app_logo, '$ownPatterns = @(' + ', '.join(q(p) for p in APP['own']) + ')', '$round = %s' % q(b['round']),
                      '$appFolder = %s' % q(APP['folder']), "$usersRoot = 'C:\\Users'"]),
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
    first = head.count('\n') + len(marks) + 2   # the bundle line of body line 1: after the header and this list
    rows = ['#   line %5d  %s' % (first + n - 1, (('  ' if line.startswith('File') else '') + line)[:150]) for n, line in marks]
    return '# ==== Contents (GENERATED; the line numbers are lines of this bundle)\n' + '\n'.join(rows) + '\n'


def part_lines():
    """Return the header lines that name each engine PowerShell part with its own SHA-256, 4 to a line, each entry
    ending in ";" (the form "<file>, sha256 <12 hex>;" that an app's test matches against its lock)."""
    rels = ['engine/ps/' + x for x in ENGINE_PARTS + WINDOW_PARTS]
    rows = [' '.join('%s, sha256 %s;' % (r, file_sha(r)) for r in rels[k:k + 4]) for k in range(0, len(rels), 4)]
    return '  Engine parts, in run order:\n' + ''.join('    %s\n' % r for r in rows)


def build(b):
    """Return the whole bundle text for one manifest bundle: the header (what it is, how to run it, its sources), the
    contents list and the body. The build id is the first 8 hex of the body's SHA-256."""
    ui_text = UI_FILE.read_text(encoding='ascii')
    body = bundle_body(b, ui_text)
    build_id = hashlib.sha256(body.encode('ascii')).hexdigest()[:8]
    modes = {a.get('mode', 'test') for a in b.get('apps', [])} or {'test'}
    sends = ' on this computer. It sends nothing.' if modes == {'deploy'} else ', then opens an Outlook draft with them (never sent; a deploy makes no draft).' if 'deploy' in modes else ', then opens an Outlook draft with them (never sent).'
    head = ('<#\n  RADE, round bundle: %s.\n'
            '  GENERATED by the RADE engine (rhope-ops/RADE engine/rade_build.py, sha256 %s; engine/rade_ui.ps1, sha256 %s) from %s; do not edit.\n'
            '%s'
            '  How to run: open Windows PowerShell ISE, File > New, paste all of this text into the script pane, press F5.\n'
            '  The RADE window opens: press Enter (or Run); it uses your Windows profile folder. It writes the files below into the task folders under\n'
            '  C:\\Users\\<DODID>\\OneDrive - United States Air Force\\RADE\\%s (replacing older copies), runs the steps,\n'
            '  and saves its results in Rounds\\%s%s No download, no admin rights.\n'
            '  To read it: the Contents list below gives the line of each part and file; each part starts with a "# ====" line.\n'
            '#>\n$buildId = \'%s\'\n$engineRelease = %d\n' % (b['title'], file_sha('engine/rade_build.py'), hashlib.sha256(ui_text.encode('ascii')).hexdigest()[:12], MANIFEST, part_lines(), APP['folder'], b['round'], sends, build_id, ENGINE_RELEASE))
    return head + contents(head, body) + body


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


# The engine's hash: every file of the engine (docs/engine.md "How an app gets the engine"): this file, each engine/ps
# part in build order, the shared UI file and the logo (path, then bytes). An app's lock still checks each file on its
# own, and a bundle's header names each file with its own hash (part_lines); this one value is what --sha prints.
ENGINE_SHA = hashlib.sha256(b''.join(rel.encode() + b'\0' + (ENGINE_ROOT / rel).read_bytes() + b'\0' for rel in
                                     ['engine/rade_build.py'] + ['engine/ps/' + x for x in ENGINE_PARTS + WINDOW_PARTS]
                                     + ['engine/rade_ui.ps1', 'assets/logo/logo-rho-128.png'])).hexdigest()
# The number of the next engine release (tag engine-v<N>); raise it before each release (docs/engine.md "Releases").
# The saved runner copy is replaced only by a bundle with a higher number (the Administrator, 2026-11-17).
ENGINE_RELEASE = 16
APP, MANIFEST = None, None

if __name__ == '__main__':
    main()
