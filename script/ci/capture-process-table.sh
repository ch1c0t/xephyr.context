#!/usr/bin/env bash
set -euo pipefail

evidence_dir="${REVIEW_EVIDENCE_DIR:-review-evidence}"
logs_dir="$evidence_dir/logs"

mkdir -p "$logs_dir"
ps -eo pid,ppid,pgid,sid,stat,cmd > "$logs_dir/processes-before-cleanup.txt" || true
