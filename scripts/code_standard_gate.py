#!/usr/bin/env python3
"""The strict parts of the code-standard check (scripts/code_standard.py): the C1 safety labels, the per-file rules, the
line-length rule, and the three gates that decide whether the ratchet baseline may take new debt.

Why: a rule that can be met with a word somewhere in a header, or with any line that names the baseline file, is met by
accident, not by work. This module holds the strict forms so the check stays under its own file cap (docs/code-standard.md C4).
What it does:
  safety_ok       a safety label starts a header line and has a value on that line
  file_rules      the per-file rules (header, safety, file size, line length) of one source file
  owner_row       a NEW docs/DECISIONS.md table row that names .code-standard.json and has the owner in its By cell
                  (an old row that was only moved, re-spaced or re-dated into the past does not count)
  owner_role      the owner role, read from the "- Owner:" line of AGENTS.md
  exists_at       a file exists at a git ref (a debt key for a file new in this change is refused)
  level           how far an opt-in rule is adopted in a config (a higher level than on main may list new debt once)
Inputs:  header text, file lines, git diff text, a repo root and a git ref.
Outputs: yes/no answers, refusal lines, and violations written into the caller's dict.
Network: none.
Writes: none (it runs git read-only commands; the check that imports it writes .code-standard.json).
Credentials: none.
Run:     imported by scripts/code_standard.py; proved by `python3 scripts/code_standard.py --test`.
"""

import re
import subprocess
from pathlib import Path

SAFETY_LABELS = ('Network:', 'Writes:', 'Credentials:')   # C1 safety: what a reviewer must find before a run
MIN_HEADER_CHARS = 60      # a header shorter than this does not say what the file is for
# A By cell with one of these marks a script or an agent, not the owner (the owner, 2026-11-17: only the owner decides).
NOT_OWNER = ('scripts/', '.py', 'agent', 'delegation')
MIN_ROW_CELLS = 4          # a DECISIONS row: date, decision, by, last
# The opt-in rules: the debt kind of each and its level in a config (0 = off). Level 2 of safety marks the strict form.
OPT_IN = {'docs': lambda c: 1 if c.get('c2') == 'full' else 0,
          'safety': lambda c: c.get('c1_safety') if type(c.get('c1_safety')) is int else int(bool(c.get('c1_safety'))),
          'line': lambda c: 1 if c.get('caps', {}).get('max_line_chars') else 0}


def safety_ok(head):
    """C1 safety: each label starts a line of the header (after comment characters and spaces) and has a value.

    Args:
        head: the header text, one header line per text line.

    Returns:
        True when Network:, Writes: and Credentials: each start a line and are followed by a value on it.
    """
    lines = head.split('\n')
    return all(any(re.match(r'^[\s#/*]*' + re.escape(x) + r'\s*\S', line) for line in lines) for x in SAFETY_LABELS)


def longest_line(lines, skip):
    """Return the length in characters of the longest line outside the generated blocks `skip` (1-based first, last)."""
    return max([len(x.rstrip('\r')) for i, x in enumerate(lines, 1) if not any(a <= i <= b for a, b in skip)] or [0])


def file_rules(v, p, lines, head, config, skip):
    """Write the per-file violations of one source file into `v`: C1 header, C1 safety, C4 file size, line length.

    Args:
        v: the violations dict {kind: {key: value}}, changed in place.
        p: the repo-relative path.
        lines: the file's lines.
        head: the header text (header_block of scripts/code_standard.py).
        config: the baseline "config".
        skip: the (first, last) line numbers of the generated blocks.

    Returns:
        None.
    """
    caps = config['caps']
    if len(head) < MIN_HEADER_CHARS:
        v['header'][p] = 1
    if config.get('c1_safety') and not safety_ok(head):
        v['safety'][p] = 1
    if len(lines) > caps['max_file_lines']:
        v['file_size'][p] = len(lines)
    longest = longest_line(lines, skip) if caps.get('max_line_chars') else 0
    if longest > caps.get('max_line_chars', longest):
        v['line'][p] = longest


def level(kind, config):
    """Return how far the opt-in rule of debt kind `kind` is adopted in `config` (0 = off or not an opt-in kind)."""
    return OPT_IN[kind](config) if kind in OPT_IN else 0


def owner_role(root):
    """Return the owner role from the "- Owner:" line of AGENTS.md, lower case, without a leading "the " ('' if none)."""
    try:
        text = (Path(root) / 'AGENTS.md').read_text(encoding='utf-8')
    except OSError:
        return ''
    m = re.search(r'^- Owner:\s*(.+?)\s*$', text, re.M)
    return re.sub(r'^the\s+', '', m.group(1).rstrip('.').lower()) if m else ''


def squeeze(text):
    """Return `text` with every run of spaces and tabs removed, so two rows that differ only in spacing are equal."""
    return re.sub(r'\s+', '', text)


def row_refusal(text, name, owner, old_rows=(), floor=''):
    """Return why a DECISIONS line is not a new owner's row for file `name`, or None when it is one.

    Args:
        text: the added line, without its leading "+".
        name: the baseline file name the decision cell must name.
        owner: the owner role (owner_role), lower case.
        old_rows: the lines of docs/DECISIONS.md at the merge base, each through squeeze().
        floor: the earliest date (YYYY-MM-DD) a new row may carry, or '' for no limit.

    Returns:
        The refusal (which rule refused it) or None.
    """
    row = text.strip()
    if not row.startswith('|'):
        return 'rule 1: not a table row (a line that starts with |)'
    cells = [c.replace('\0', '|').strip() for c in row.replace('\\|', '\0').strip('|').split('|')]
    if len(cells) < MIN_ROW_CELLS:
        return 'rule 1: a table row has at least %d cells' % MIN_ROW_CELLS
    if name not in ' | '.join(cells[1:-2]):   # a "|" inside the decision text makes more cells: By is the one before last
        return 'rule 2: the decision cell does not name ' + name
    by = cells[-2].lower()
    bad = [x for x in NOT_OWNER if x in by]
    if bad:
        return 'rule 3: the By cell names a script or an agent (%s)' % bad[0]
    if not owner:
        return 'rule 4: AGENTS.md has no "- Owner:" line to name the owner'
    if not re.fullmatch(r'(the\s+)?' + re.escape(owner) + r'(\s*\(.*\))?', by):
        return 'rule 4: the By cell is not the owner alone (%s)' % owner
    if squeeze(row) in old_rows:
        return 'rule 5: the row is not new (it is on main already; a moved or re-spaced row is no decision)'
    if floor and not (re.fullmatch(r'\d{4}-\d{2}-\d{2}', cells[0]) and cells[0] >= floor):
        return 'rule 6: the row is dated before this change started (%s); an old row that was edited is no decision' % floor
    return None


def owner_row(diff, name, owner, old_text='', floor=''):
    """Check the added lines of a docs/DECISIONS.md diff for the owner's new row that opens the ratchet gate.

    Args:
        diff: the text of `git diff <merge base> -- docs/DECISIONS.md`.
        name: the baseline file name.
        owner: the owner role (owner_role).
        old_text: docs/DECISIONS.md at the merge base ('' when there is none).
        floor: the earliest date a new row may carry (the day before the merge base's commit), or ''.

    Returns:
        (True, []) when an added table row is new, names `name` and has the owner alone in its By cell; else (False,
        one refusal line for each added line that names `name`, with the rule that refused it).
    """
    old_rows = {squeeze(x) for x in old_text.split('\n') if x.strip()}
    refusals = []
    for line in diff.split('\n'):
        if not line.startswith('+') or line.startswith('+++') or name not in line:
            continue
        why = row_refusal(line[1:], name, owner, old_rows, floor)
        if why is None:
            return True, []
        refusals.append('REFUSED  docs/DECISIONS.md line (%s): %s' % (why, line[1:61]))
    return False, refusals


def exists_at(root, ref, path):
    """True when `path` exists in the commit `ref` (git cat-file -e); a file that does not is new in this change."""
    return subprocess.run(['git', '-C', str(root), 'cat-file', '-e', '%s:%s' % (ref, path)],
                          capture_output=True).returncode == 0
