require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe "review evidence reporter" do
  let(:repository_root) { File.expand_path("../..", __dir__) }
  let(:script) { File.join(repository_root, "script", "review_evidence.rb") }
  let!(:evidence_directory) { Dir.mktmpdir("xephyr-review-evidence-") }
  let!(:worker_evidence_directory) { Dir.mktmpdir("xephyr-worker-evidence-") }

  after do
    FileUtils.rm_rf(evidence_directory)
    FileUtils.rm_rf(worker_evidence_directory)
  end

  def invoke(evidence_directory, *arguments)
    environment = {
      "REVIEW_EVIDENCE_DIR" => evidence_directory,
      "GITHUB_REPOSITORY" => "ch1c0t/xephyr.context",
      "REVIEW_PR_NUMBER" => "6",
      "REVIEW_PR_HEAD_SHA" => "head-sha",
      "REVIEW_BASE_SHA" => "base-sha"
    }

    Open3.capture3(environment, RbConfig.ruby, script, *arguments, chdir: repository_root)
  end

  it "records command output and exit status in a reviewer-readable report" do
    _, _, init_status = invoke(evidence_directory, "init")
    expect(init_status).to be_success

    checks = %w[crystal-dependencies build crystal-library-specs crystal-integration-specs ruby-cli-specs]
    checks.each do |name|
      command = if name == "crystal-integration-specs"
        [RbConfig.ruby, "-e", 'warn "integration failure"; exit 7']
      else
        [RbConfig.ruby, "-e", "puts \"#{name} passed\""]
      end
      _, _, status = invoke(evidence_directory, "run", name, *command)
      if name == "crystal-integration-specs"
        expect(status.exitstatus).to eq(7)
      else
        expect(status).to be_success
      end
    end

    _, _, finalize_status = invoke(evidence_directory, "finalize")
    expect(finalize_status.exitstatus).to eq(1)

    manifest = JSON.parse(File.read(File.join(evidence_directory, "manifest.json")))
    expect(manifest.dig("pull_request", "number")).to eq(6)
    expect(manifest.dig("commit", "pull_request_head_sha")).to eq("head-sha")
    expect(manifest.dig("checks", "passed")).to eq(4)
    expect(manifest.dig("checks", "failed")).to eq(1)
    expect(manifest.dig("checks", "missing")).to be_empty
    expect(manifest.dig("checks", "result")).to eq("failed")

    results = JSON.parse(File.read(File.join(evidence_directory, "test-results", "commands.json")))
    expect(results.map { |result| result.fetch("status") }.count("passed")).to eq(4)
    expect(results.map { |result| result.fetch("status") }.count("failed")).to eq(1)
    failed_log = results.find { |result| result.fetch("status") == "failed" }.fetch("log")
    expect(File.read(File.join(evidence_directory, failed_log))).to include("integration failure")

    summary = File.read(File.join(evidence_directory, "review-summary.md"))
    expect(summary).to include("Requirement-to-evidence map")
    expect(summary).to include("crystal-integration-specs")
    expect(summary).to include("FAILED")
    expect(summary).to include("## Toolchain")
  end

  it "merges evidence artifacts from independent jobs and preserves their logs" do
    _, _, init_status = invoke(evidence_directory, "init")
    expect(init_status).to be_success

    worker = worker_evidence_directory
    FileUtils.mkdir_p(File.join(worker, "test-results"))
    FileUtils.mkdir_p(File.join(worker, "logs"))
    FileUtils.mkdir_p(File.join(worker, "traces"))

    File.write(File.join(worker, "manifest.json"), JSON.generate({
      "workflow" => {"job" => "library"},
      "commit" => {"checked_out_sha" => "worker-sha"}
    }))
    File.write(File.join(worker, "test-results", "001-crystal-library-specs.log"), "21 examples, 0 failures\n")
    File.write(File.join(worker, "test-results", "commands.jsonl"), JSON.generate({
      "name" => "crystal-library-specs",
      "command" => ["crystal", "spec", "spec/library"],
      "started_at_utc" => "2026-11-13T00:00:00Z",
      "finished_at_utc" => "2026-11-13T00:00:01Z",
      "duration_seconds" => 1.0,
      "exit_code" => 0,
      "status" => "passed",
      "log" => "test-results/001-crystal-library-specs.log"
    }) + "\n")
    File.write(File.join(worker, "logs", "daemon.log"), "daemon output\n")
    File.write(File.join(worker, "traces", "lifecycle.jsonl"), "{\"event\":\"stopped\"}\n")

    _, _, merge_status = invoke(evidence_directory, "merge", worker)
    expect(merge_status).to be_success

    _, _, verify_status = invoke(evidence_directory, "verify")
    expect(verify_status).to be_success

    records = JSON.parse(File.read(File.join(evidence_directory, "test-results", "commands.json")))
    expect(records.length).to eq(1)
    expect(records.first.fetch("name")).to eq("crystal-library-specs")
    expect(records.first.fetch("artifact")).to eq(File.basename(worker_evidence_directory))
    expect(File.read(File.join(evidence_directory, records.first.fetch("log")))).to include("21 examples")
    expect(File.read(File.join(evidence_directory, "logs", "daemon.log"))).to include("daemon output")
    expect(File.read(File.join(evidence_directory, "traces", "lifecycle.jsonl"))).to include("stopped")
    expect(Dir.glob(File.join(evidence_directory, "workers", "*.json")).length).to eq(1)

    _, _, finalize_status = invoke(evidence_directory, "finalize")
    expect(finalize_status.exitstatus).to eq(1)

    manifest = JSON.parse(File.read(File.join(evidence_directory, "manifest.json")))
    expect(manifest.dig("checks", "passed")).to eq(1)
    expect(manifest.dig("checks", "missing")).to include("build", "crystal-integration-specs", "ruby-cli-specs")
    expect(manifest.fetch("evidence_sources")).to eq([File.basename(worker_evidence_directory)])
  end

  it "fails verification when a recorded command failed" do
    _, _, init_status = invoke(evidence_directory, "init")
    expect(init_status).to be_success

    _, _, run_status = invoke(
      evidence_directory,
      "run",
      "build",
      RbConfig.ruby,
      "-e",
      "exit 9"
    )
    expect(run_status.exitstatus).to eq(9)

    _, _, verify_status = invoke(evidence_directory, "verify")
    expect(verify_status.exitstatus).to eq(1)
  end

end
