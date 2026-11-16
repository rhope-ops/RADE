#!/usr/bin/env python3
"""Run the REAL RADE window on Windows PowerShell 5.1 (the Windows job, .github/workflows/window.yml).

Linux cannot draw Windows Forms: there tests/engine_test.sh runs the window's logic against stand-in types. This script
builds the sample bundle, swaps its addresses for local files (as engine_test.sh does), puts the test user
tests/window_real_driver.ps1 in front and runs it with powershell.exe. The driver prints one WIN line and the layout
lines for each card and saves one PNG of each card.

Usage: python tests/window_real.py OUT_DIR
Pass = every run ends with "WIN closed=True", prints no "LAYOUT " line (the engine's layout self-check), a SCALE line,
and no card scrolls at a size larger than the smallest; the first run draws the 3 question cards of the hand step
and each run in the smallest window draws the text question (exit 0). Output: OUT_DIR/<run>/*.png
(NN-answer-yesno, NN-answer-pick, NN-answer-text), out.txt.
"""
import importlib.util
import json
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
SMALLEST = "811x469"   # the only size at which the text of a card may scroll (the buttons stay in view)
RUNS = [
    ("deploy-full", 1, "done", "0", "", False),
    # the next two start where "deploy-full" ended (the same user folder): the application is installed, so the
    # Maintenance card shows, with "Uninstall" at the right end (1020 wide) and on its own row (811 wide)
    ("deploy-616", 1, "done", "1", "1020x616", False),
    ("deploy-tour-small", 1, "fail", "1", "811x469", False),
    ("test-small", 0, "done", "0", "811x469", False),
    # the same bundle with every text at its limit (docs/window-design.md "Text lengths")
    ("long-616", 1, "fail", "1", "1020x616", True),
    ("long-small", 0, "done", "0", "811x469", True),
    # the same bundle in the real Windows PowerShell ISE host, as on a work computer (run_ise)
    ("ise-host", 1, "done", "0", "", False),
]
ISE = "ise-host"

WORDS = "readiness tracker for each unit member with a reminder before an item is due and one page for the commander "


def fill(text, n):
    """text made n characters long with plain words (a text at its limit, with spaces so that it can wrap)."""
    return (text + " " + WORDS * 4)[:n].rstrip().ljust(n, "x")


def stretch(m, limits):
    """Every text of the manifest that has a limit, at its limit. Step names keep their place in "steps", "after" and "collect"."""
    for b in m["bundles"]:
        names = {}
        for st in b["steps"]:
            names[st["name"]] = fill(st["name"], limits["step name"])
            st["name"] = names[st["name"]]
            st["note"] = fill(st.get("note", "Note"), limits["step note"])
            st["help"] = fill(st.get("help", "Help"), limits["step help"])
            if st.get("kind") == "guide":
                st["guide"] = [fill(g, limits["guide line"]) for g in st.get("guide", [])]
                st["doneText"] = fill(st.get("doneText", "Done"), limits["doneText"])
            for a in st.get("answers", []):
                # the text question: one long first sentence (no "?", "." or ":"), so its headline shrinks and then wraps;
                # the others: a short first sentence and a long body line under it
                p = a["prompt"].replace("?", "").replace(".", "").replace(":", "") if a["kind"] == "text" else a["prompt"]
                a["prompt"] = fill(p, limits["answer prompt"])
                if "choices" in a:
                    a["choices"] = [fill(c, limits["answer choice"]) for c in a["choices"]]
            st["after"] = [names.get(a, a) for a in st.get("after", [])]
            if not st["after"]:
                del st["after"]
        for c in b.get("collect", []):
            c["step"] = names.get(c.get("step"), c.get("step"))
        for a in b["apps"]:
            a["name"] = fill(a["name"], limits["application name"])
            a["summary"] = fill(a["summary"], limits["summary"])
            if a.get("version"):
                a["version"] = (a["version"] + "-rc.1234567890")[:limits["version"]]
            a["steps"] = [names[x] for x in a["steps"]]
    return m


def file_url(p):
    return pathlib.Path(p).resolve().as_uri()


def bundle(t, long, keep=None):
    app = t / "app"
    shutil.copytree(ROOT / "tests" / "fixture-app", app)
    m = json.loads((ROOT / "schemas" / "examples" / "sample-manifest.json").read_text(encoding="utf-8"))
    qa = json.loads((ROOT / "tests" / "fixture-app" / "answers.json").read_text(encoding="utf-8"))   # the hand step's questions, as in tests/engine_test.sh
    [st for st in m["bundles"][0]["steps"] if st["name"] == qa["step"]][0]["answers"] = qa["answers"]
    names = [a["name"] for a in m["bundles"][0]["apps"]]
    if long:
        sp = importlib.util.spec_from_file_location("rade_build", str(ROOT / "engine" / "rade_build.py"))
        eng = importlib.util.module_from_spec(sp)
        sp.loader.exec_module(eng)
        m = stretch(m, eng.TEXT_LIMITS)
        names = [a["name"] for a in m["bundles"][0]["apps"]]
    (app / "scripts" / "paste_bundles.json").write_text(json.dumps(m), encoding="utf-8")
    r = subprocess.run([sys.executable, str(ROOT / "engine" / "rade_build.py"), "--app-root", str(app)], capture_output=True, text=True)
    if r.returncode:
        sys.exit("FAIL build of the sample bundle\n" + r.stdout + r.stderr)
    (t / "go.md").write_text("", encoding="utf-8")
    (t / "rel.json").write_text(json.dumps({"apps": dict((n, "9.0.0") for n in names)}), encoding="utf-8")   # a newer version on the app page: the notice shows
    users = (keep or t) / "wu"
    (users / "test1234" / "OneDrive - United States Air Force").mkdir(parents=True, exist_ok=True)
    s = (app / "scripts" / "gov" / "paste" / "SAMPLE-R01-round-r1.ps1").read_text(encoding="utf-8")
    go = file_url(t / "go.md")
    for pat, new in [
        # the NIPR guard: the test copy gives a computer name with the NIPR label, as tests/engine_test.sh does (the engine has no switch)
        (r"(?m)^function Get-OwnFqdn .*", "function Get-OwnFqdn { return 'pc01.area52.example.invalid' }"),
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


def run_ise(t, env):
    """The bundle in the Windows PowerShell ISE host: ISE runs its profile on the thread that runs a pasted script, so the
    profile runs the test copy of the bundle and then ends ISE. ISE has no standard output: the driver writes its lines to a
    file (RADE_T_LOG). Returns the text, or None when this computer has no ISE."""
    exe = pathlib.Path(os.environ.get("WINDIR", r"C:\Windows")) / "System32" / "WindowsPowerShell" / "v1.0" / "powershell_ise.exe"
    if not exe.exists():
        return None
    log = t / "ise.txt"
    q = subprocess.run(["powershell.exe", "-NoProfile", "-Command", "[Environment]::GetFolderPath('MyDocuments')"], capture_output=True, text=True)
    prof = pathlib.Path(q.stdout.strip()) / "WindowsPowerShell" / "Microsoft.PowerShellISE_profile.ps1"
    prof.parent.mkdir(parents=True, exist_ok=True)
    prof.write_text("$env:USERPROFILE = '%s'; try { . '%s' } catch { [System.IO.File]::AppendAllText('%s', 'WIN DRIVER-ERROR ' + $_.Exception.Message + \"`r`n\") } finally { [Environment]::Exit(0) }\n" % (env["USERPROFILE"], t / "w.ps1", log), encoding="utf-8-sig")
    try:
        subprocess.run([str(exe)], env=dict(env, RADE_T_LOG=str(log), PSExecutionPolicyPreference="Bypass", USERPROFILE=os.environ.get("USERPROFILE", "")), timeout=420, stdin=subprocess.DEVNULL)
        text = ""
    except subprocess.TimeoutExpired:
        text = "WIN HARNESS-TIMEOUT\n"
    finally:
        prof.unlink()
    return (log.read_text(encoding="utf-8", errors="replace") if log.exists() else "WIN BAD the ISE run wrote no line\n") + text


def main():
    out = pathlib.Path(sys.argv[1]).resolve()
    bad = 0
    home = pathlib.Path(tempfile.mkdtemp())   # the user folder the three "deploy" runs share
    maint = 0
    for name, app, hand, tour, size, long in RUNS:
        t = pathlib.Path(tempfile.mkdtemp())
        users = bundle(t, long, home if name.startswith("deploy-") else None)
        d = out / name
        d.mkdir(parents=True, exist_ok=True)
        first = name == RUNS[0][0]
        env = dict(os.environ, RADE_T_OUT=str(d), RADE_T_APP=str(app), RADE_T_HAND=hand, RADE_T_TOUR=tour, RADE_T_SIZE=size, USERPROFILE=str(users / "test1234"),
                   RADE_T_PROBE="1" if first or name == ISE else "")
        if name == ISE:
            text = run_ise(t, env)
            if text is None:
                print("== %s: NOT RUN, powershell_ise.exe is not on this computer" % name)
                shutil.rmtree(t, ignore_errors=True)
                continue
        else:
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
        for l in lines:
            if l.startswith(("WIN", "LAYOUT ", "No window could open", "Layout self-check")) or (first and l.startswith("MEASURE")):
                print("   " + l[:170])
        if not closed:
            print("   --- last lines ---")
            for l in lines[-25:]:
                print("   " + l[:300])
        scrolls = [l for l in lines if l.startswith("WIN scrolls ")]
        why = []
        if not closed:
            why.append("the window did not reach its end")
        if layout:
            why.append("%d layout defects" % len(layout))
        if scrolls and size != SMALLEST:
            why.append("a card scrolls at a size where none may: " + scrolls[0][12:])
        if not any(l.startswith("WIN line Layout self-check: ") for l in lines):
            why.append("no line of the layout self-check")
        if not any(l.startswith("WIN SCALE ") for l in lines):
            why.append("no SCALE line of the layout self-check")
        got = {re.sub(r"^\d+-", "", p.stem) for p in d.glob("*-answer-*.png")}
        if first and got != {"answer-yesno", "answer-pick", "answer-text"}:
            why.append("the question cards (answer-yesno, answer-pick, answer-text) were not all drawn: %s" % sorted(got))
        if size == SMALLEST and hand == "done" and "answer-text" not in got:
            why.append("the text question (answer-text) was not drawn in the smallest window")
        if first or name == ISE:   # minimize and restore with the window messages of the taskbar button (R25)
            rs = [l for l in lines if l.startswith("WIN restore ")]
            if len(rs) != 2 or any(" ok=True " not in l for l in rs):
                why.append("minimize and restore (2 WIN restore lines with ok=True are needed): %s" % [l[:60] for l in rs])
            if name == ISE and not any("host=Windows PowerShell ISE Host" in l for l in rs):
                why.append("the run was not in the ISE host")
        broken = [l for l in lines if l.startswith(("WIN PNG-FAILED", "WIN DRIVER-ERROR", "WIN TIMEOUT", "WIN BAD"))]
        if broken:
            why.append(broken[0][:120])
        flat = [l for l in lines if l.startswith("WIN png=") and int(l.rsplit("=", 1)[1]) < 20]
        if flat:
            why.append("a picture with fewer than 20 colors (the window was not drawn): " + flat[0])
        maint += sum(1 for l in lines if l.startswith("WIN card=") and " view=maint " in l)
        if why:
            bad += 1
            print("   FAIL " + name + ": " + "; ".join(why))
        shutil.rmtree(t, ignore_errors=True)
    if maint < 2:
        bad += 1
        print("   FAIL the Maintenance card showed %d times, 2 at least are needed (1020 and 811 wide)" % maint)
    print("WINDOW runs=%d bad=%d maintenance-cards=%d" % (len(RUNS), bad, maint))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
