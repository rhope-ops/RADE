"""RADE's own finders for the content check (the extension point of the kit's scripts/check_content_scan.py: its header
gives the interface). RADE replaces the kit's finder of the kind milhost with its linear-time finder milhosts() of
scripts/check_content_milhosts.py (RADE decision 2A, 2026-11-16: the pattern stays as it is; the finder makes its
time linear in the line).

What it does: REPLACE = {"milhost": [find_milhost]}; find_milhost(line) yields (start, end, host) for each match.
Inputs:  one line of text (the scanner calls find_milhost per line).
Outputs: (start, end, value) spans; with --test, one "ok" or "FAIL" line per case and exit code 0 or 1.
Network: none.
Writes: none.
Credentials: none.
Run:     loaded by scripts/check_content_scan.py; `python3 scripts/check_content_local.py --test` is the self-test
         (scripts/check.sh runs it). Target: Python 3.8+.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))   # the scanner loads this file by path, not by import
import check_content_milhosts  # noqa: E402 - RADE's pattern and linear finder; it does not import the scanner


def find_milhost(line):
    """Yield the span and text of each military or DoD cloud host name in one line, in linear time.

    Args:
        line: one line of text.

    Returns:
        An iterator of (start, end, host) tuples, leftmost first (the matches of MILHOST.finditer).
    """
    for m in check_content_milhosts.milhosts(line):
        yield m.start(), m.end(), m.group()


REPLACE = {"milhost": [find_milhost]}


def self_test():
    """Run RADE's milhost cases through the kit's scanner, with this module loaded as the project's finders.

    Returns:
        0 when every case passed, else 1.
    """
    import check_content_scan            # imported only here: the module must not import the scanner when it is loaded
    import check_content_test_milhosts   # RADE's cases (scripts/check_content_test_milhosts.py)
    failed = []

    def check(label, good):
        """Print one result line and remember a failure.

        Args:
            label: the text of the result line.
            good: True when the case passed.
        """
        print(("ok   " if good else "FAIL ") + label)
        if not good:
            failed.append(label)

    def expect(name, text, kinds, dod=False):
        """Scan one text with the kit's scanner and check that the finding kinds are exactly these.

        Args:
            name: the label of the case.
            text: the text to scan.
            kinds: the finding kinds the scan must give.
            dod: True to run the DoD checks.
        """
        got = sorted({k for _, _, k, _ in check_content_scan.scan_text(text, "t", [], set(), dod)})
        check(f"{name}: {got}", got == sorted(kinds))

    check(f"the scanner uses this finder for milhost ({check_content_scan.LOCAL or 'no local module'})",
          [f.__name__ for f in check_content_scan.FINDERS["milhost"]] == ["find_milhost"]
          and "replaces milhost" in check_content_scan.LOCAL)
    check_content_test_milhosts.run(check, expect)
    print(f"CHECK_CONTENT_LOCAL {'FAIL' if failed else 'PASS'} ({len(failed)} failed)")
    return 1 if failed else 0


if __name__ == "__main__" and "--test" in sys.argv[1:]:
    sys.exit(self_test())
