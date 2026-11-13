#!/usr/bin/env bash
set -euo pipefail

inputs_dir="review-evidence-inputs"
shopt -s nullglob
artifacts=()

for directory in "$inputs_dir"/review-evidence-*; do
  [[ -d "$directory" ]] || continue
  artifacts+=("$directory")
done

if (("${#artifacts[@]}")); then
  ruby script/review_evidence.rb merge "${artifacts[@]}"
else
  echo "No worker evidence artifacts were downloaded."
fi

rm -rf "$inputs_dir"
