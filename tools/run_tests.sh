#!/usr/bin/env bash
# Runs the headless test suite. Set GODOT to the Godot 4.7 binary if it isn't
# on PATH as "godot". Extra arguments are passed to the runner as a filter.
set -uo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

# Importing builds the class_name cache that --script needs.
"$GODOT" --headless --path . --import >/dev/null 2>&1

output="$("$GODOT" --headless --path . --script res://tests/run_tests.gd -- "$@" 2>&1)"
status=$?
echo "$output"

if [ $status -ne 0 ]; then
  exit $status
fi
if grep -qE "SCRIPT ERROR|Parse Error|^ERROR:" <<<"$output"; then
  echo "Errors were logged during the test run." >&2
  exit 1
fi
