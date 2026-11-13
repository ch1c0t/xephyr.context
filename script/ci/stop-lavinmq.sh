#!/usr/bin/env bash
set -euo pipefail

pid_file="${RUNNER_TEMP:?RUNNER_TEMP must be set}/lavinmq/lavinmq.pid"
if [[ -f "$pid_file" ]]; then
  kill "$(cat "$pid_file")" 2>/dev/null || true
fi
