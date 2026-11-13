#!/usr/bin/env bash
set -euo pipefail

runner_temp="${RUNNER_TEMP:?RUNNER_TEMP must be set}"
github_env="${GITHUB_ENV:?GITHUB_ENV must be set}"
display="${XEPHYR_CONTEXT_TEST_DISPLAY:-:1000}"
display_number="${display#:}"
socket="/tmp/.X11-unix/X$display_number"

# Keep the integration display outside the low-number range used by xephyrd.
Xvfb "$display" -screen 0 640x480x24 -nolisten tcp >"$runner_temp/xvfb.log" 2>&1 &
echo "$!" > "$runner_temp/xvfb.pid"

for attempt in $(seq 1 30); do
  if [[ -S "$socket" ]]; then
    echo "DISPLAY=$display" >> "$github_env"
    echo "XEPHYR_CONTEXT_TEST_DISPLAY=$display" >> "$github_env"
    exit 0
  fi
  sleep 1
done

cat "$runner_temp/xvfb.log"
echo "Timed out waiting for Xvfb ($display)" >&2
exit 1
