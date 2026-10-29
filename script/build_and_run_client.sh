#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-run}"
case "$MODE" in run|--debug|--verify) ;; *) echo 'Usage: build_and_run_client.sh [run|--debug|--verify]' >&2; exit 2;; esac
# Stop only clients launched from this checkout.
for PID in $(pgrep -x tux-target || true); do
  if [[ "$(ps -p "$PID" -o comm=)" == "$ROOT/dist/Tux Target.app/Contents/MacOS/tux-target" ]]; then
    kill "$PID"
  fi
done
"$ROOT/script/build_client_macos.sh"
export XDG_CONFIG_HOME="$ROOT/runtime-macos-client/config"
export XDG_CACHE_HOME="$ROOT/runtime-macos-client/xdg-cache"
if [[ "$MODE" == --debug ]]; then
  cd "$ROOT/runtime-macos-client"
  exec lldb -- "$ROOT/dist/Tux Target.app/Contents/MacOS/tux-target"
fi
open -n "$ROOT/dist/Tux Target.app" \
  --env "XDG_CONFIG_HOME=$XDG_CONFIG_HOME" --env "XDG_CACHE_HOME=$XDG_CACHE_HOME" \
  --stdout "$ROOT/runtime-macos-client/client-stdout.log" \
  --stderr "$ROOT/runtime-macos-client/client-stderr.log"
if [[ "$MODE" == --verify ]]; then
  sleep 5
  pgrep -f "$ROOT/dist/Tux Target.app/Contents/MacOS/tux-target" >/dev/null
  echo 'Client process is running. This does not validate rendering or gameplay.'
fi
