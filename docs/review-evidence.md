# Pull request review evidence

The CI workflow uploads a `review-evidence` artifact for every run. The artifact is generated from the exact checked-out commit and is intended to make test scope, execution results, and runtime diagnostics inspectable without committing transient files to the repository.

## Contents

- `manifest.json` identifies the checked-out commit, pull request head and base commits, workflow run, runner platform, and toolchain versions.
- `review-summary.md` gives a human-readable check table and maps key requirements to their verification and evidence files.
- `test-results/commands.json` is the machine-readable list of recorded commands, exit codes, durations, and log paths.
- `test-results/commands.jsonl` is the append-only record used to produce the JSON report.
- `test-results/*.log` contains each recorded command's combined standard output and standard error.
- `logs/` contains Xvfb, LavinMQ, and process-table diagnostics when available.
- `inspection/` contains the exact PNG and OCR text produced by the inspector executable integration test, plus metadata describing the assertions.

The artifact is uploaded even when tests fail. The reporting script records each check independently, allowing later checks and diagnostic collection to run after a failure. It also tracks the five expected CI commands and marks the report incomplete when an expected command never ran. Finalization fails the job for failed or missing checks; artifact-upload failure is configured not to hide the original test result.

## Local use

The same reporter can be used when reproducing CI failures locally:

```sh
ruby script/review_evidence.rb init
ruby script/review_evidence.rb run build bundle exec rake
ruby script/review_evidence.rb run crystal-library-specs crystal spec spec/library
ruby script/review_evidence.rb run crystal-integration-specs crystal spec spec/integration
ruby script/review_evidence.rb run ruby-cli-specs bundle exec rspec
ruby script/review_evidence.rb finalize
```

Set `REVIEW_EVIDENCE_DIR` to change the output directory. The `run` command accepts an executable and argument array; it does not evaluate the command through a shell. A failed command is recorded and its exit code returned. `finalize` writes the aggregate report and exits nonzero if any recorded command failed.

## Extending the evidence

When a new behavior is important to a reviewer, add its requirement, verification, and retained artifact to the matrix in `script/review_evidence.rb`. Prefer evidence that is produced by the real executable or integration path. Keep transient evidence in the uploaded artifact rather than in source control, and avoid including credentials, private environment variables, or unrelated user data in logs.

## Automatic pull request comment

For `pull_request` workflow runs, CI publishes one bot-managed comment on the PR after evidence finalization and artifact upload have completed.

The comment reports:
- The exact PR head commit tested.
- The overall result: passed, checks failed, evidence incomplete, evidence artifact unavailable, or evidence generation failed.
- Each recorded command's result, duration, and exit code.
- Missing expected checks and failed checks.
- Links to the workflow run and, when upload succeeds, the downloadable evidence artifact.

The publisher updates the existing comment identified by `<!-- review-evidence -->`; it does not create a new comment for each commit or rerun. It fingerprints the tested commit, check outcomes, missing checks, and artifact availability. Identical reruns are therefore skipped, while a new PR commit, a changed check result, or a change in artifact availability updates the comment.

Before publishing, it fetches the current PR head SHA. A run whose tested SHA is no longer the current PR head is ignored, so a slower older run cannot overwrite newer evidence. The publisher runs only for pull-request events, not pushes to `main` or manual workflow dispatches.

Comment publishing has `pull-requests: write` permission and is configured not to change the test result if commenting itself fails. GitHub normally provides read-only workflow tokens to workflows triggered by pull requests from forks, so those runs may upload evidence successfully but be unable to create or update the PR comment. In that case, the workflow run and artifact remain available through the Actions UI.

The upload action's artifact URL is used rather than constructing a download URL. Artifact links require repository access and expire with the artifact retention period.
