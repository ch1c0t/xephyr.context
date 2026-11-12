#!/usr/bin/env ruby

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "time"

class ReviewEvidence
  SCHEMA_VERSION = 1
  REQUIREMENT_MATRIX = [
    {
      requirement: "Framebuffer publication reflects real X11 changes and suppresses unchanged frames",
      verification: "spec/integration/daemon_spec.cr",
      evidence: "test-results/*crystal-integration-specs.log"
    },
    {
      requirement: "Spatial window metadata follows window creation and destruction",
      verification: "spec/integration/daemon_spec.cr",
      evidence: "test-results/*crystal-integration-specs.log"
    },
    {
      requirement: "The daemon exits cleanly on SIGTERM and releases X11 resources",
      verification: "spec/integration/daemon_spec.cr",
      evidence: "test-results/*crystal-integration-specs.log"
    },
    {
      requirement: "Library state, replay, and wait_until contracts remain correct",
      verification: "spec/library/**/*_spec.cr",
      evidence: "test-results/*crystal-library-specs.log"
    },
    {
      requirement: "The inspector can replay a frame, write a valid PNG, and recognize expected text",
      verification: "spec/integration/inspect_spec.cr",
      evidence: "inspection/frame_*.png, inspection/frame_*.txt, inspection/evidence.json"
    },
    {
      requirement: "The command-line interface continues to expose its documented help output",
      verification: "spec/cli/**/*_spec.rb",
      evidence: "test-results/*ruby-cli-specs.log"
    }
  ].freeze

  def initialize
    @repository_root = File.expand_path(ENV.fetch("GITHUB_WORKSPACE", File.expand_path("..", __dir__)))
    @evidence_dir = File.expand_path(ENV.fetch("REVIEW_EVIDENCE_DIR", "review-evidence"), @repository_root)
  end

  def call(arguments)
    command = arguments.shift

    case command
    when "init"
      initialize_evidence
      0
    when "run"
      run_command(arguments)
    when "finalize"
      finalize_evidence
    else
      warn <<~USAGE
        Usage:
          ruby script/review_evidence.rb init
          ruby script/review_evidence.rb run NAME COMMAND [ARG ...]
          ruby script/review_evidence.rb finalize

        REVIEW_EVIDENCE_DIR may override the output directory.
      USAGE
      2
    end
  rescue StandardError => error
    warn "review evidence: #{error.class}: #{error.message}"
    2
  end

  private

  def initialize_evidence
    raise "refusing to use the repository root as the evidence directory" if @evidence_dir == @repository_root
    raise "refusing to use the filesystem root as the evidence directory" if @evidence_dir == File::SEPARATOR

    FileUtils.rm_rf(@evidence_dir)
    %w[test-results logs inspection traces].each do |directory|
      FileUtils.mkdir_p(File.join(@evidence_dir, directory))
    end

    write_json("manifest.json", build_manifest)
    puts "Initialized review evidence at #{relative_path(@evidence_dir)}"
  end

  def run_command(arguments)
    name = arguments.shift
    command = arguments
    unless name && name.match?(/\A[a-zA-Z0-9][a-zA-Z0-9._-]*\z/) && !command.empty?
      raise "run requires a safe step name and a command"
    end

    ensure_initialized
    records_path = File.join(@evidence_dir, "test-results", "commands.jsonl")
    sequence = File.exist?(records_path) ? File.foreach(records_path).count + 1 : 1
    log_name = format("%03d-%s.log", sequence, name)
    log_path = File.join(@evidence_dir, "test-results", log_name)
    started_at = Time.now.utc
    monotonic_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    puts "\n$ #{command.join(' ')}"
    exit_code = execute_and_log(command, log_path)
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - monotonic_start

    record = {
      "name" => name,
      "command" => command,
      "started_at_utc" => started_at.iso8601(6),
      "finished_at_utc" => Time.now.utc.iso8601(6),
      "duration_seconds" => duration.round(3),
      "exit_code" => exit_code,
      "status" => exit_code.zero? ? "passed" : "failed",
      "log" => relative_path(log_path)
    }

    File.open(records_path, "a") { |file| file.puts(JSON.generate(record)) }
    puts "[#{record.fetch('status').upcase}] #{name} (#{record.fetch('duration_seconds')}s; exit #{exit_code})"
    exit_code
  end

  def execute_and_log(command, log_path)
    exit_code = 127
    File.open(log_path, "wb") do |log|
      begin
        Open3.popen2e(*command, chdir: @repository_root) do |stdin, output, waiter|
          stdin.close
          output.each do |chunk|
            $stdout.write(chunk)
            $stdout.flush
            log.write(chunk)
          end
          exit_code = waiter.value.exitstatus || 1
        end
      rescue SystemCallError => error
        message = "Unable to start command: #{error.class}: #{error.message}\n"
        $stderr.write(message)
        log.write(message)
      end
    end
    exit_code
  end

  def finalize_evidence
    ensure_initialized
    records = read_command_records
    write_json("test-results/commands.json", records)

    manifest = read_json("manifest.json")
    manifest["finalized_at_utc"] = Time.now.utc.iso8601(6)
    manifest["environment"] = environment_details
    manifest["checks"] = {
      "total" => records.length,
      "passed" => records.count { |record| record.fetch("status") == "passed" },
      "failed" => records.count { |record| record.fetch("status") == "failed" }
    }
    write_json("manifest.json", manifest)
    write_summary(records, manifest)

    puts "Wrote #{relative_path(File.join(@evidence_dir, 'manifest.json'))}"
    puts "Wrote #{relative_path(File.join(@evidence_dir, 'review-summary.md'))}"
    records.any? { |record| record.fetch("status") != "passed" } ? 1 : 0
  end

  def build_manifest
    {
      "schema_version" => SCHEMA_VERSION,
      "generated_at_utc" => Time.now.utc.iso8601(6),
      "repository" => ENV["GITHUB_REPOSITORY"],
      "commit" => {
        "checked_out_sha" => git_value("rev-parse", "HEAD"),
        "pull_request_head_sha" => ENV["REVIEW_PR_HEAD_SHA"],
        "base_sha" => ENV["REVIEW_BASE_SHA"],
        "ref" => ENV["GITHUB_REF"],
        "head_ref" => ENV["GITHUB_HEAD_REF"]
      },
      "pull_request" => {
        "number" => pull_request_number,
        "head_ref" => ENV["GITHUB_HEAD_REF"]
      },
      "workflow" => {
        "name" => ENV["GITHUB_WORKFLOW"],
        "job" => ENV["GITHUB_JOB"],
        "event" => ENV["GITHUB_EVENT_NAME"],
        "run_id" => ENV["GITHUB_RUN_ID"],
        "run_attempt" => ENV["GITHUB_RUN_ATTEMPT"],
        "run_url" => workflow_run_url
      },
      "environment" => environment_details
    }
  end

  def environment_details
    {
      "distribution" => distribution_name,
      "kernel" => command_output("uname", "-srmo"),
      "architecture" => RbConfig::CONFIG["host_cpu"],
      "toolchain" => {
        "crystal" => command_output("crystal", "--version"),
        "shards" => command_output("shards", "--version"),
        "ruby" => command_output("ruby", "--version"),
        "bundler" => command_output("bundle", "--version")
      },
      "runner_image_os" => ENV["ImageOS"],
      "runner_image_version" => ENV["ImageVersion"]
    }.compact
  end

  def distribution_name
    return unless File.exist?("/etc/os-release")

    line = File.foreach("/etc/os-release").find { |item| item.start_with?("PRETTY_NAME=") }
    line&.split("=", 2)&.last&.strip&.sub(/\A"/, "")&.sub(/"\z/, "")
  end

  def command_output(*command)
    output, status = Open3.capture2e(*command, chdir: @repository_root)
    return unless status.success?

    output.lines.first(3).join.strip
  rescue SystemCallError
    nil
  end

  def git_value(*arguments)
    command_output("git", *arguments)&.lines&.first&.strip
  end

  def pull_request_number
    value = ENV["REVIEW_PR_NUMBER"]
    return value.to_i if value && !value.empty?

    event_path = ENV["GITHUB_EVENT_PATH"]
    return unless event_path && File.file?(event_path)

    JSON.parse(File.read(event_path)).dig("pull_request", "number")
  rescue JSON::ParserError
    nil
  end

  def workflow_run_url
    server = ENV["GITHUB_SERVER_URL"]
    repository = ENV["GITHUB_REPOSITORY"]
    run_id = ENV["GITHUB_RUN_ID"]
    return unless server && repository && run_id

    "#{server}/#{repository}/actions/runs/#{run_id}"
  end

  def read_command_records
    path = File.join(@evidence_dir, "test-results", "commands.jsonl")
    return [] unless File.file?(path)

    File.readlines(path, chomp: true).reject(&:empty?).map { |line| JSON.parse(line) }
  end

  def read_json(path)
    JSON.parse(File.read(File.join(@evidence_dir, path)))
  end

  def write_json(path, value)
    File.write(File.join(@evidence_dir, path), JSON.pretty_generate(value) + "\n")
  end

  def write_summary(records, manifest)
    lines = [
      "# Pull request review evidence",
      "",
      "This report was generated by CI. The attached command logs are the source of truth for check output.",
      "",
      "## Run identity",
      "",
      "| Field | Value |",
      "| --- | --- |",
      table_row("Repository", manifest["repository"]),
      table_row("Pull request", manifest.dig("pull_request", "number")),
      table_row("Checked-out commit", manifest.dig("commit", "checked_out_sha")),
      table_row("PR head commit", manifest.dig("commit", "pull_request_head_sha")),
      table_row("Base commit", manifest.dig("commit", "base_sha")),
      table_row("Event", manifest.dig("workflow", "event")),
      table_row("Workflow run", manifest.dig("workflow", "run_url")),
      table_row("Platform", [manifest.dig("environment", "distribution"), manifest.dig("environment", "kernel")].compact.join(" / ")),
      "",
      "## Checks",
      "",
      "| Step | Status | Exit | Duration | Log | Command |",
      "| --- | --- | ---: | ---: | --- | --- |"
    ]

    if records.empty?
      lines << "| No recorded checks | — | — | — | — | — |"
    else
      records.each do |record|
        lines << "| #{escape_table(record['name'])} | #{record['status'].upcase} | #{record['exit_code']} | #{record['duration_seconds']}s | `#{record['log']}` | `#{escape_table(record['command'].join(' '))}` |"
      end
    end

    lines.concat([
      "",
      "## Requirement-to-evidence map",
      "",
      "| Requirement | Verification | Evidence |",
      "| --- | --- | --- |"
    ])

    REQUIREMENT_MATRIX.each do |item|
      lines << "| #{escape_table(item[:requirement])} | `#{item[:verification]}` | `#{item[:evidence]}` |"
    end

    lines.concat([
      "",
      "## Evidence contents",
      "",
      "- `manifest.json`: commit identity, pull request metadata, workflow identity, platform, and toolchain versions.",
      "- `test-results/commands.json`: machine-readable command results.",
      "- `test-results/commands.jsonl`: append-only command result records.",
      "- `test-results/*.log`: complete combined standard output and standard error for each recorded command.",
      "- `logs/`: captured Xvfb and LavinMQ logs, when those services started.",
      "- `inspection/`: the PNG and OCR output produced by the inspector integration spec.",
      "",
      "## Interpretation",
      "",
      "A check is marked passed only when its command exited with status 0. A green workflow is still required; this report does not replace CI status checks.",
      ""
    ])

    File.write(File.join(@evidence_dir, "review-summary.md"), lines.join("\n"))
  end

  def table_row(label, value)
    "| #{label} | #{escape_table(value || 'not available')} |"
  end

  def escape_table(value)
    value.to_s.gsub("|", "\\|").gsub("\n", " ")
  end

  def relative_path(path)
    expanded = File.expand_path(path)
    return "." if expanded == @evidence_dir

    expanded.delete_prefix("#{@evidence_dir}/")
  end

  def ensure_initialized
    raise "evidence directory is not initialized; run init first" unless File.file?(File.join(@evidence_dir, "manifest.json"))
    FileUtils.mkdir_p(File.join(@evidence_dir, "test-results"))
  end
end

exit ReviewEvidence.new.call(ARGV)
