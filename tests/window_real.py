#!/usr/bin/env python3
"""Run the REAL RADE window on Windows PowerShell 5.1 (the Windows job, .github/workflows/window.yml).

Linux cannot draw Windows Forms: there tests/engine_test.sh runs the window's logic against stand-in types. This script
builds the sample bundle, swaps its addresses for local files (as engine_test.sh does), puts the test user
tests/window_real_driver.ps1 in front and runs it with powershell.exe. The driver prints one WIN line and the layout
lines for each card and saves one PNG of each card.

Usage: python tests/window_real.py OUT_DIR
Pass = every run ends with "WIN closed=True" and prints no "LAYOUT " line (exit 0). Output: OUT_DIR/<run>/*.png, out.txt.
"""
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
# name, application (0 = test, 1 = deploy), hand step, tour, window size in 100 % pixels ("" = as the engine sets it;
# 1020x616 = 1920 x 1080 at 150 % scaling; 811x469 = 95 % of the work area of 1280 x 800 at 150 % scaling)
RUNS = [
    ("deploy-full", 1, "done", "0", ""),
    ("deploy-616", 1, "done", "1", "1020x616"),
    ("deploy-tour-small", 1, "fail", "1", "811x469"),
    ("test-small", 0, "done", "0", "811x469"),
]


def file_url(p):
    return pathlib.Path(p).resolve().as_uri()


def bundle(t):
    app = t / "app"
    shutil.copytree(ROOT / "tests" / "fixture-app", app)
    shutil.copy(ROOT / "schemas" / "examples" / "sample-manifest.json", app / "scripts" / "paste_bundles.json")
    r = subprocess.run([sys.executable, str(ROOT / "engine" / "rade_build.py"), "--app-root", str(app)], capture_output=True, text=True)
    if r.returncode:
        sys.exit("FAIL build of the sample bundle\n" + r.stdout + r.stderr)
    (t / "go.md").write_text("", encoding="utf-8")
    (t / "rel.json").write_text('{ "apps": { "Sample app (deploy)": "9.0.0", "Sample app": "9.0.0" } }', encoding="utf-8")
    users = t / "wu"
    (users / "test1234" / "OneDrive - United States Air Force").mkdir(parents=True)
    s = (app / "scripts" / "gov" / "paste" / "SAMPLE-R01-round-r1.ps1").read_text(encoding="utf-8")
    go = file_url(t / "go.md")
    for pat, new in [
        (r"(?m)^\$usersRoot = 'C:\\Users'", "$usersRoot = '%s'" % users),
        (r"(?m)^\$goUrl = '.*'", "$goUrl = '%s'" % go),
        (r"(?m)^\$releaseUrl = '.*'", "$releaseUrl = '%s'" % file_url(t / "rel.json")),
        (r"\$checkGate = \$true", "$checkGate = $false"),
        (r"(?m)^\$sitePrefix = 'https://usaf\.dps\.mil/sites/'", "$sitePrefix = 'https://rade-test.invalid/sites/'"),
    ]:
        s, n = re.subn(pat, lambda m, new=new: new, s)
        if not n:
            sys.exit("FAIL the bundle has no line for " + pat)
    s = s.replace("https://raw.githubusercontent.com/example-org/sample-app/v1.0.0/", file_url(app) + "/")
    s = s.replace("https://example-org.github.io/sample-app", go).replace("https://example.invalid/import", go)
    driver = (ROOT / "tests" / "window_real_driver.ps1").read_text(encoding="utf-8")
    (t / "w.ps1").write_text(driver + "\n" + s, encoding="utf-8-sig")   # a byte order mark: Windows PowerShell 5.1 reads the file as UTF-8
    return users


def main():
    out = pathlib.Path(sys.argv[1]).resolve()
    bad = 0
    for name, app, hand, tour, size in RUNS:
        t = pathlib.Path(tempfile.mkdtemp())
        users = bundle(t)
        d = out / name
        d.mkdir(parents=True, exist_ok=True)
        env = dict(os.environ, RADE_T_OUT=str(d), RADE_T_APP=str(app), RADE_T_HAND=hand, RADE_T_TOUR=tour, RADE_T_SIZE=size, USERPROFILE=str(users / "test1234"))
        try:
            r = subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(t / "w.ps1")], env=env, capture_output=True, text=True, timeout=420, stdin=subprocess.DEVNULL, errors="replace")
            text = r.stdout + r.stderr
        except subprocess.TimeoutExpired as e:
            text = (e.stdout or b"").decode("utf-8", "replace") + "\nWIN HARNESS-TIMEOUT"
        (d / "out.txt").write_text(text, encoding="utf-8")
        lines = text.splitlines()
        layout = [l for l in lines if l.startswith("LAYOUT ")]
        closed = any(l.startswith("WIN closed=True") for l in lines)
        cards = sum(1 for l in lines if l.startswith("WIN card="))
        print("== %s: cards=%d layout-lines=%d closed=%s png=%d" % (name, cards, len(layout), closed, len(list(d.glob("*.png")))))
        first = name == RUNS[0][0]
        for l in lines:
            if l.startswith(("WIN", "LAYOUT ", "No window could open")) or (first and l.startswith("MEASURE")):
                print("   " + l[:300])
        if not closed:
            print("   --- last lines ---")
            for l in lines[-25:]:
                print("   " + l[:300])
        if layout or not closed:
            bad += 1
        shutil.rmtree(t, ignore_errors=True)
    print("WINDOW runs=%d bad=%d" % (len(RUNS), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
