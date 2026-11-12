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
