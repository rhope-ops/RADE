#!/usr/bin/env bash
# RADE project checks (run last by scripts/check.sh). Pass = exit 0.
# Manifest contract: schemas/rade-manifest.schema.json plus cross-references (scripts/check_manifest.py).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
python3 scripts/check_manifest.py
# Engine (moved from rhope-ops/90-161.Z, 2026-11-14): it compiles. Each app's own tests build and check its bundles.
python3 -m py_compile engine/rade_build.py
# Engine file list (apps lock these files; the release workflow signs the list): the trace runs and names the engine.
python3 scripts/engine_files.py | grep -q '  engine/rade_build.py$'
# RADE page (index.html): its application list is valid, and each entry names a repository and a manifest path.
python3 -c "import json,re; c=json.load(open('apps.json')); assert c['apps'] and all(re.fullmatch(r'[\w.-]+/[\w.-]+', a['repo']) and a['manifest'].endswith('.json') for a in c['apps']), 'apps.json'"
# App canary (the Administrator, 2026-11-15): this engine and schema still build every real application in apps.json
# (a read-only copy of each app's main branch; needs network access to github.com).
python3 tests/check_apps_test.py
python3 scripts/check_apps.py
# Engine behavior (deploy v1): build the sample bundle and run it in pwsh text mode.
bash tests/engine_test.sh
