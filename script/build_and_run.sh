#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-run}"
case "$MODE" in run|--verify|--debug|--logs) ;; *) echo 'Usage: build_and_run.sh [run|--verify|--debug|--logs]' >&2; exit 2;; esac
# Stop only the instance launched by this checkout, never another server.
PIDFILE="$ROOT/runtime-macos/server.pid"
if [[ -f "$PIDFILE" ]]; then
  OLD_PID="$(cat "$PIDFILE")"
  if [[ "$OLD_PID" =~ ^[0-9]+$ ]] && ps -p "$OLD_PID" -o command= | rg -Fq "$ROOT/build-macos-server/tux-target-srv"; then
    kill "$OLD_PID"
  fi
fi
"$ROOT/script/build_server_macos.sh"
python3 "$ROOT/script/prepare_runtime_macos.py"
cd "$ROOT/runtime-macos"
if [[ "$MODE" == --debug ]]; then
  exec lldb -- "$ROOT/build-macos-server/tux-target-srv"
fi
"$ROOT/build-macos-server/tux-target-srv" &
SERVER_PID=$!
echo "$SERVER_PID" > "$PIDFILE"
trap 'kill "$SERVER_PID" 2>/dev/null || true; rm -f "$PIDFILE"' EXIT
if [[ "$MODE" == --verify ]]; then
  sleep 4
  kill -0 "$SERVER_PID"
  echo 'Server remained running for 4 seconds; stopping verification instance.'
else
  wait "$SERVER_PID"
fi
