#!/usr/bin/env python3
"""Run the REAL RADE window on Windows PowerShell 5.1 (the Windows job, .github/workflows/window.yml).

Linux cannot draw Windows Forms: there tests/engine_test.sh runs the window's logic against stand-in types. This script
builds the sample bundle, swaps its addresses for local files (as engine_test.sh does), puts the test user
tests/window_real_driver.ps1 in front and runs it with powershell.exe. The driver prints one WIN line and the layout
lines for each card and saves one PNG of each card.

Usage: python tests/window_real.py OUT_DIR
Pass = every run ends with "WIN closed=True", prints no "LAYOUT " line (the engine's layout self-check), a SCALE line,
and no card scrolls at a size larger than the smallest, except a hand card ("Your turn"), whose text may scroll at
any size (the Administrator, 2026-11-17); the first run draws the 3 question cards of the hand step
and each run in the smallest window draws the text question; a first window of a Windows profile draws the 5 tour cards,
and a test round draws the cards answerfail and feedback (R31) (exit 0). Output: OUT_DIR/<run>/*.png
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
    # the Maintenance card and its tools screen at 150 % and with a contrast theme (the PFM's preview, 2026-11-20)
    ("device150-maint", 1, "done", "0", "956x1081", False),
    ("contrast-maint", 1, "done", "0", "", False),
    ("test-small", 0, "done", "0", "811x469", False),
    # the same bundle with every text at its limit (docs/window-design.md "Text lengths")
    ("long-616", 1, "fail", "1", "1020x616", True),
    ("long-small", 0, "done", "0", "811x469", True),
    # the work computer of round R32 (the Administrator, 2026-11-18): Windows scaling 150 %, the window on the left half of a
    # 1920 x 1080 screen (956 x 1081 real pixels). The job's screen draws at 100 %, so the test copy of the bundle makes the
    # form scale by 1.5 and reports 144 dpi (DEVICE_150 below); the fonts then grow by 1.5 as they do on that computer.
    ("device150-half", 0, "done", "0", "956x1081", False),
    # UI standard v1 (the Administrator, 2026-11-20; docs/ui-standard.md "Proof"): the same test round at 125 % and 200 %
    # (scaled as the 150 % run is: device()), and once with a Windows contrast theme on (CONTRAST: the window takes the
    # system colors from its first frame; the job's theme itself stays as it is).
    ("device125-full", 0, "done", "0", "", False),
    ("device200-full", 0, "done", "0", "", False),
    ("contrast-full", 0, "done", "0", "", False),
]
# Swaps for a "device150-" run: the form's sizes are given at 64 dpi, so Windows Forms scales it by 1.5 on a 96 dpi screen,
# and the form's dpi reads 144 (the engine's $ui.Sc and its font factor follow it), as on a screen with 150 % scaling.
def device(k):
    """The swaps that make the form scale by k on a 96 dpi screen and report 96 * k dpi (as DEVICE_150 does for 1.5)."""
    return [(DEVICE_150[0][0], "$ui.Form.AutoScaleDimensions = New-Object System.Drawing.SizeF(%s, %s)" % (96 / k, 96 / k)),
            (DEVICE_150[1][0], "if ($d -gt 0) { $ui.Dpi = $d * %s }" % k)]


# The swap of the contrast run: the window reads a contrast theme as on ($ui.HighOn), so every color is a system color.
CONTRAST = [(r"\$ui\.HighOn = \{ try \{ return \[bool\]\[System\.Windows\.Forms\.SystemInformation\]::HighContrast \} catch \{ return \$false \} \}",
             "$ui.HighOn = { return $true }")]
DEVICE_150 = [
    (r"\$ui\.Form\.AutoScaleDimensions = New-Object System\.Drawing\.SizeF\(96, 96\)", "$ui.Form.AutoScaleDimensions = New-Object System.Drawing.SizeF(64, 64)"),
    (r"if \(\$d -gt 0\) \{ \$ui\.Dpi = \$d \}", "if ($d -gt 0) { $ui.Dpi = $d * 1.5 }"),
    # the step title of R32 that left no room for the bar beside it: the bar must stay on the title's line ($ui.FitBar)
    (r"'Check this computer'", "'Make the test list and library'"),
]
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
            st["title"] = fill(st.get("title", st["name"]), limits["step title"])
            st["note"] = fill(st.get("note", "Note"), limits["step note"])
            st["help"] = fill(st.get("help", "Help"), limits["step help"])
            if st.get("kind") == "guide":
                # as many numbered lines as the soft limit allows ('guide lines'), each at its length limit, then the unnumbered extras
                extra = [fill(g, limits["guide line"]) for g in st.get("guide", []) if not re.match(r"\d+\.\s+\S", g)]  # the engine's pattern
                st["guide"] = [fill("%d. Select" % k, limits["guide line"]) for k in range(1, limits["guide lines"] + 1)] + extra
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


def bundle(t, long, keep=None, swaps=()):
    app = t / "app"
    shutil.copytree(ROOT / "tests" / "fixture-app", app)
    m = json.loads((ROOT / "schemas" / "examples" / "sample-manifest.json").read_text(encoding="utf-8"))
    qa = json.loads((ROOT / "tests" / "fixture-app" / "answers.json").read_text(encoding="utf-8"))   # the hand step's questions, as in tests/engine_test.sh
    for st in m["bundles"][0]["steps"]:
        if st["name"] in qa["titles"]:
            st["title"] = qa["titles"][st["name"]]
        if st["name"] == qa["step"]:
            st["answers"] = qa["answers"]
            st.update(qa["set"])
    names = [a["name"] for a in m["bundles"][0]["apps"]]
    if long:
        sp = importlib.util.spec_from_file_location("rade_build", str(ROOT / "engine" / "rade_build.py"))
        eng = importlib.util.module_from_spec(sp)
        sp.loader.exec_module(eng)
        m = stretch(m, eng.TEXT_LIMITS)
        names = [a["name"] for a in m["bundles"][0]["apps"]]
    # R31 (docs/reviews/2026-11-19-r31-plan.md): a step of the test application that shows only questions (E2), with an answer
    # that means a failure and a question that depends on the other answer (E3); the first step says what it is doing (L7).
    b0 = m["bundles"][0]
    b0["steps"][0]["doing"] = "Checking the sample files."
    b0["steps"].append({"name": "T05 Sample questions r1", "dir": "T05", "file": "", "kind": "guide", "guide": [], "answersOnly": True, "answers": [
        {"key": "page", "prompt": "What does the page show?", "kind": "pick", "choices": ["The list", "An error"], "failOn": ["An error"]},
        {"key": "more", "prompt": "Does the list show two rows?", "kind": "yesno", "showIf": {"key": "page", "in": ["The list"]}}]})
    b0["apps"][0]["steps"].append("T05 Sample questions r1")
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
    ] + list(swaps):
        s, n = re.subn(pat, lambda m, new=new: new, s)
        if not n:
            sys.exit("FAIL the bundle has no line for " + pat)
    s = s.replace("https://raw.githubusercontent.com/example-org/sample-app/v1.0.0/", file_url(app) + "/")
    s = s.replace("https://example-org.github.io/sample-app", go).replace("https://example.invalid/import", go)
    driver = (ROOT / "tests" / "window_real_driver.ps1").read_text(encoding="utf-8")
    (t / "w.ps1").write_text(driver + "\n" + s, encoding="utf-8-sig")   # a byte order mark: Windows PowerShell 5.1 reads the file as UTF-8
    return users


def r32_why(lines, name):
    """Say what a run misses of the R32 window fixes (docs/DECISIONS.md 2026-11-18): the mouse wheel and the step row.

    Args:
        lines: the output lines of the run.
        name: the name of the run ("device150-" runs also check the step row of the Run card).

    Returns:
        A list of texts, one for each fault (empty = nothing is missing).
    """
    why = []
    wheel = [l for l in lines if l.startswith("WIN wheel ")]
    scrolls = [l for l in lines if l.startswith("WIN scrolls ")]
    if any(not l.rstrip().endswith("moved=True") for l in wheel) or len(wheel) != len(scrolls):
        why.append("the mouse wheel did not move the text of each card that scrolls (%d of %d)" % (len(wheel), len(scrolls)))
    if any(l.startswith("WIN r32 ") and " error=" in l for l in lines):
        why.append("an r32 measure line has an error")
    if name.startswith("device150-"):
        rows = [re.search(r" name=(\d+)/(\d+) bar=(\d+)/.* frac=(\d+)/", l) for l in lines if l.startswith("WIN r32 ") and "-run " in l]
        rows = [tuple(int(x) for x in m.groups()) for m in rows if m]
        # the bar and the count start inside the title's rows: they are on its line, not on a line of their own under it
        if len(rows) < 3 or any(not (top <= bar < top + high and top <= frac < top + high) for top, high, bar, frac in rows):
            why.append("the step's bar or count is not on the title's line: %s" % rows[:4])
    return why


def r31_why(lines, app, fresh):
    """Say what a run misses of the cards of the R31 brief (docs/reviews/2026-11-19-r31-plan.md).

    Args:
        lines: the output lines of the run.
        app: the application of the run (0 = the test application).
        fresh: True when the run starts on a new Windows profile, so the tour shows.

    Returns:
        A list of reasons (empty when nothing is missing): a first window draws the 5 tour cards; a test round draws
        the error card of an answer that means a failure and its last card.
    """
    views = [re.sub(r"^WIN card=\d+-(\S+) .*$", r"\1", l) for l in lines if l.startswith("WIN card=")]
    why = []
    if fresh and views.count("tour") != 5:
        why.append("the tour drew %d cards, not 5" % views.count("tour"))
    if app == 0 and not {"answerfail", "feedback"} <= set(views):
        why.append("a test round did not draw the cards answerfail and feedback")
    return why


def restore_why(lines):
    """Say what a run misses of the Restore cards (engine-v31; the mark card, engine-v32): a run that shows the
    Maintenance screen draws all three.

    Args:
        lines: the run's output lines.

    Returns:
        A list of reasons (empty when nothing is missing).
    """
    cards = [l for l in lines if l.startswith("WIN card=")]
    drawn = {v for v in ("restmark", "restpick", "restconfirm") if any((" view=%s " % v) in l for l in cards)}
    if any(" view=tools " in l for l in cards) and drawn != {"restmark", "restpick", "restconfirm"}:
        return ["the Maintenance screen showed, but the Restore cards were not all drawn: %s" % sorted(drawn)]
    if drawn and "WIN restore-mark saved=True view=restpick" not in lines:
        return ["the Restore mark card did not save the mark and go on to the backup list"]
    if drawn and not any(" view=restpick " in l and "[Remove test-site mark]" in l for l in cards):
        return ["the Restore backup card of a marked site did not show \"Remove test-site mark\""]
    if drawn and "WIN restore-unmark-button shown=True focused=False row-focused=True" not in lines:
        return ["\"Remove test-site mark\" was not on the backup card, or the focus was not on the newest backup row"]
    if drawn and not ("WIN restore-unmarked-site view=restmark" in lines and "WIN restore-nobackup-button view=toolres shown=True" in lines):
        return ["after the removal the mark card did not show, or the no-backup card of a marked site had no button"]
    if drawn and "WIN restore-unmark gone=True view=toolres" not in lines:
        return ["\"Remove test-site mark\" did not remove the mark and show the result card"]
    if drawn and not any(" view=restconfirm " in l and " p=Test site: " in l for l in cards):
        return ["the Restore confirm card did not show \"Test site: <name>\" as its first line"]
    got = [int(m.group(1)) for m in (re.match(r"WIN restore-lines (\d+) visible=True", l) for l in lines) if m]
    if drawn and not (got and min(got) >= 2):
        return ["the Restore confirm card did not show its 2 count lines"]
    return []


def swaps_for(name):
    """The swaps of a run's test copy, by the start of its name: device150-, device125-, device200- (the scale) or contrast-.
    200 % on the job's 1920 x 1080 screen is 960 x 540 at 100 %, smaller than 1020 x 616, so its text may scroll too (main)."""
    for k, v in (("device150-", DEVICE_150), ("device125-", device(1.25)), ("device200-", device(2)), ("contrast-", CONTRAST)):
        if name.startswith(k):
            return v
    return ()


def ui_why(lines, d, name):
    """Say what a run misses of UI standard v1 (docs/ui-standard.md "Proof"): its inventory, and the contrast run's colors.

    Args:
        lines: the output lines of the run.
        d: the run's output folder (inventory.jsonl is there).
        name: the name of the run ("contrast-" runs must take the system colors).

    Returns:
        A list of reasons (empty = nothing is missing). Prints the INVENTORY line.
    """
    why, inv = [], d / "inventory.jsonl"
    print("   INVENTORY lines=%d" % (len(inv.read_text(encoding="utf-8-sig").splitlines()) if inv.exists() else 0))
    if not inv.exists():
        why.append("no inventory (RADE_INVENTORY)")
    if name.startswith("contrast-") and not any(l.startswith("WIN high=True") for l in lines):
        why.append("the contrast run did not take the system colors (no WIN high=True line)")
    return why


def screen():
    """Ask for a screen of 1920 x 1080, so the window of the "device150-" run fits (the job's screen is smaller).
    A job that cannot set it goes on. Returns the SCREEN line to print (what the screen is now)."""
    cmd = "Set-DisplayResolution -Width 1920 -Height 1080 -Force; (Get-DisplayResolution | Out-String).Trim()"
    rs = subprocess.run(["powershell.exe", "-NoProfile", "-Command", cmd], capture_output=True, text=True, errors="replace")
    return "SCREEN " + " ".join((rs.stdout + rs.stderr).split())[:160]


def main():
    out = pathlib.Path(sys.argv[1]).resolve()
    bad = 0
    home = pathlib.Path(tempfile.mkdtemp())   # the user folder the "deploy" and "-maint" runs share
    maint = 0
    for name, app, hand, tour, size, long in RUNS:
        t = pathlib.Path(tempfile.mkdtemp())
        users = bundle(t, long, home if (shared := name.startswith("deploy-") or name.endswith("-maint")) else None, swaps_for(name))   # -maint: the installed app
        d = out / name
        d.mkdir(parents=True, exist_ok=True)
        env = dict(os.environ, RADE_T_OUT=str(d), RADE_T_APP=str(app), RADE_T_HAND=hand, RADE_T_TOUR=tour, RADE_T_SIZE=size, USERPROFILE=str(users / "test1234"), RADE_INVENTORY=str(d / "inventory.jsonl"))
        try:
            r = subprocess.run(["powershell.exe", "-NoProfile", "-File", str(t / "w.ps1")], env=env, capture_output=True, text=True, timeout=420, stdin=subprocess.DEVNULL, errors="replace")
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
            if l.startswith(("WIN", "LAYOUT ", "No window could open", "Layout self-check")) or (first and l.startswith("MEASURE")):
                print("   " + l[:170])
        if not closed:
            print("   --- last lines ---")
            for l in lines[-25:]:
                print("   " + l[:300])
        # a hand card ("Your turn") may scroll at any size (the Administrator, 2026-11-17); every other card only at the smallest
        scrolls = [l for l in lines if l.startswith("WIN scrolls ") and not l.rstrip().endswith("-hand")]
        why = r31_why(lines, app, name == RUNS[0][0] or not shared) + r32_why(lines, name) + restore_why(lines)   # R31: tour and test-round cards; R32: wheel, step row; engine-v31: Restore cards
        if not closed:
            why.append("the window did not reach its end")
        if layout:
            why.append("%d layout defects" % len(layout))
        why += ui_why(lines, d, name)
        why += ["a card scrolls at a size where none may: " + scrolls[0][12:]] if scrolls and size != SMALLEST and not name.startswith("device200-") else []
        if not any(l.startswith("WIN line Layout self-check: ") for l in lines):
            why.append("no line of the layout self-check")
        if not any(l.startswith("WIN SCALE ") for l in lines):
            why.append("no SCALE line of the layout self-check")
        got = {re.sub(r"^\d+-", "", p.stem) for p in d.glob("*-answer-*.png")}
        if first and got != {"answer-yesno", "answer-pick", "answer-text"}:
            why.append("the question cards (answer-yesno, answer-pick, answer-text) were not all drawn: %s" % sorted(got))
        if size == SMALLEST and hand == "done" and "answer-text" not in got:
            why.append("the text question (answer-text) was not drawn in the smallest window")
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
    print(screen())
    sys.exit(main())
