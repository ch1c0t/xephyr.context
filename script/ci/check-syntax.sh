#!/usr/bin/env bash
set -euo pipefail

bash -n script/test

while IFS= read -r -d '' path; do
  bash -n "$path"
done < <(find script -type f -name '*.sh' -print0)

node --check script/ci/publish-review-evidence-comment.js
