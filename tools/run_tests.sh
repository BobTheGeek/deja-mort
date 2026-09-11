#!/usr/bin/env bash
# Runs the gdUnit4 suite headless. Same command locally and in CI.
#
#   tools/run_tests.sh                 # whole suite
#   tools/run_tests.sh --add tests/sim # one folder
#
# --ignoreHeadlessMode is required: gdUnit4 refuses --headless by default because
# InputEvents do not fire there. Nothing under sim/ touches Input, so this is safe.
# If a presentation test ever needs real input, run it outside this script.
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ARGS=("$@")
if [ ${#ARGS[@]} -eq 0 ]; then
	ARGS=(--add tests)
fi

exec "$GODOT_BIN" --headless --path "$PROJECT_ROOT" \
	-s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
	--ignoreHeadlessMode --continue "${ARGS[@]}"
