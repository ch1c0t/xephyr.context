#!/usr/bin/env bash
set -euo pipefail

runner_temp="${RUNNER_TEMP:?RUNNER_TEMP must be set}"
evidence_dir="${REVIEW_EVIDENCE_DIR:-review-evidence}"
logs_dir="$evidence_dir/logs"

mkdir -p "$logs_dir"

if [[ -f "$runner_temp/lavinmq/lavinmq.log" ]]; then
  cp "$runner_temp/lavinmq/lavinmq.log" "$logs_dir/lavinmq.log"
fi

if [[ -f "$runner_temp/xvfb.log" ]]; then
  cp "$runner_temp/xvfb.log" "$logs_dir/xvfb.log"
fi
