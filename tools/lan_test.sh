#!/usr/bin/env bash
# Two copies of the game on this computer play together over real LAN
# sockets: discovery, joining, cooking a pizza across both kitchens with
# real drag gestures, results, lobby, arcade and the host leaving.
# Needs xvfb-run (or a desktop session). Screenshots of both phones go to
# $SCREENSHOT_DIR (default: build/lan_screenshots). Set GODOT like run_tests.sh.
set -uo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
SCREENSHOT_DIR="${SCREENSHOT_DIR:-$PWD/build/lan_screenshots}"
SCENE="res://tools/lan_test/lan_runner.tscn"
LOGS="$(mktemp -d)"
mkdir -p "$SCREENSHOT_DIR"

"$GODOT" --headless --path . --import >/dev/null 2>&1

run() {  # role
  local cmd=("$GODOT" --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 "$SCENE" -- "$1" "$SCREENSHOT_DIR")
  if command -v xvfb-run >/dev/null 2>&1; then
    timeout 240 xvfb-run -a -s "-screen 0 1280x720x24" "${cmd[@]}" > "$LOGS/$1.log" 2>&1
  else
    timeout 240 "${cmd[@]}" > "$LOGS/$1.log" 2>&1
  fi
}

run host & host_pid=$!
sleep 2
run client & client_pid=$!
wait $host_pid; host_status=$?
wait $client_pid; client_status=$?

status=0
for role in host client; do
  echo "===== $role ====="
  grep -vE "^OpenGL|V-Sync|set_use_vsync|^$" "$LOGS/$role.log"
  if grep -qE "SCRIPT ERROR|Parse Error|^ERROR:" "$LOGS/$role.log"; then
    status=1
  fi
done
if [ $host_status -ne 0 ] || [ $client_status -ne 0 ]; then
  echo "host exited with $host_status, client with $client_status" >&2
  status=1
fi
[ $status -eq 0 ] && echo "LAN test passed." || echo "LAN test FAILED." >&2
exit $status
