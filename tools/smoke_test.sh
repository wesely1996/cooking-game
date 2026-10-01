#!/usr/bin/env bash
# Runs the real game screens (menu, level select, a bit of Pizza Night with
# real taps, drags and swipes, results) and fails on any logged error.
#
# With xvfb-run available it uses a virtual display, checks touch input and
# saves screenshots to $SCREENSHOT_DIR (default: build/screenshots). Without
# it, it runs headless and skips the input checks. Set GODOT like run_tests.sh.
set -uo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
SCREENSHOT_DIR="${SCREENSHOT_DIR:-$PWD/build/screenshots}"
SCENE="res://tools/screenshots/screenshot_runner.tscn"

"$GODOT" --headless --path . --import >/dev/null 2>&1

if command -v xvfb-run >/dev/null 2>&1; then
  mkdir -p "$SCREENSHOT_DIR"
  output="$(timeout 180 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . \
    --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 "$SCENE" -- "$SCREENSHOT_DIR" 2>&1)"
else
  echo "xvfb-run not found: running headless without input checks."
  output="$(timeout 180 "$GODOT" --headless --path . "$SCENE" 2>&1)"
fi
status=$?
echo "$output"
if [ $status -ne 0 ]; then
  echo "Smoke test exited with $status." >&2
  exit 1
fi
if grep -qE "SCRIPT ERROR|Parse Error|^ERROR:" <<<"$output"; then
  echo "Errors were logged during the smoke test." >&2
  exit 1
fi
if ! grep -q "14_recipe_coming_soon" <<<"$output"; then
  echo "The smoke test did not reach the end of the run." >&2
  exit 1
fi
echo "Smoke test passed."
