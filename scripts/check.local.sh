#!/usr/bin/env bash
# RADE project checks (run last by scripts/check.sh). Pass = exit 0.
# Manifest contract: schemas/rade-manifest.schema.json plus cross-references (scripts/check_manifest.py).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
python3 scripts/check_manifest.py
# Engine (moved from rhope-ops/90-161.Z, 2026-11-14): it compiles. Each app's own tests build and check its bundles.
python3 -m py_compile engine/rade_build.py
