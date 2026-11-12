require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe "review evidence reporter" do
  let(:repository_root) { File.expand_path("../..", __dir__) }
  let(:script) { File.join(repository_root, "script", "review_evidence.rb") }
  let!(:evidence_directory) { Dir.mktmpdir("xephyr-review-evidence-") }

  after do
    FileUtils.rm_rf(evidence_directory)
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

    _, _, passed_status = invoke(
      evidence_directory,
      "run",
      "library-specs",
      RbConfig.ruby,
      "-e",
      'puts "library specs passed"'
    )
    expect(passed_status).to be_success

    _, _, failed_status = invoke(
      evidence_directory,
      "run",
      "integration-specs",
      RbConfig.ruby,
      "-e",
      'warn "integration failure"; exit 7'
    )
    expect(failed_status.exitstatus).to eq(7)

    _, _, finalize_status = invoke(evidence_directory, "finalize")
    expect(finalize_status.exitstatus).to eq(1)

    manifest = JSON.parse(File.read(File.join(evidence_directory, "manifest.json")))
    expect(manifest.dig("pull_request", "number")).to eq(6)
    expect(manifest.dig("commit", "pull_request_head_sha")).to eq("head-sha")
    expect(manifest.dig("checks", "passed")).to eq(1)
    expect(manifest.dig("checks", "failed")).to eq(1)

    results = JSON.parse(File.read(File.join(evidence_directory, "test-results", "commands.json")))
    expect(results.map { |result| result.fetch("status") }).to eq(["passed", "failed"])
    expect(File.read(File.join(evidence_directory, results.last.fetch("log")))).to include("integration failure")

    summary = File.read(File.join(evidence_directory, "review-summary.md"))
    expect(summary).to include("Requirement-to-evidence map")
    expect(summary).to include("integration-specs")
    expect(summary).to include("FAILED")
  end
end
