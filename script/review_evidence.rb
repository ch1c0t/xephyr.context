#!/usr/bin/env ruby

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "time"

class ReviewEvidence
  SCHEMA_VERSION = 1
  EXPECTED_CHECKS = %w[
    crystal-dependencies
    build
    crystal-library-specs
    crystal-integration-specs
    ruby-cli-specs
  ].freeze
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
      evidence: "logs/xephyr.context-daemon.log, traces/daemon-lifecycle.jsonl"
    },
    {
      requirement: "Window creation and destruction are reflected in spatial metadata",
      verification: "spec/integration/daemon_spec.cr",
      evidence: "logs/x11-window-snapshots.log, traces/daemon-lifecycle.jsonl"
    },
    {
      requirement: "Spatial metadata arriving after a framebuffer produces a fresh state without another frame",
      verification: "spec/library/each_mutation_spec.cr",
      evidence: "test-results/*crystal-library-specs.log"
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
    when "merge"
      merge_evidence(arguments)
    when "verify"
      verify_commands
    when "finalize"
      finalize_evidence
    else
      warn <<~USAGE
        Usage:
          ruby script/review_evidence.rb init
          ruby script/review_evidence.rb run NAME COMMAND [ARG ...]
          ruby script/review_evidence.rb merge PATH [PATH ...]
          ruby script/review_evidence.rb verify
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


  def merge_evidence(arguments)
    raise "merge requires one or more evidence artifact directories" if arguments.empty?
    ensure_initialized

    records_path = File.join(@evidence_dir, "test-results", "commands.jsonl")
    sequence = File.exist?(records_path) ? File.foreach(records_path).count + 1 : 1
    imported_artifacts = []

    arguments.each do |argument|
      source = File.expand_path(argument, @repository_root)
      unless File.directory?(source)
        warn "Skipping missing evidence artifact directory: #{argument}"
        next
      end

      artifact_name = File.basename(source)
      imported_artifacts << artifact_name
      import_worker_manifest(source, artifact_name)
      sequence = import_command_records(source, artifact_name, records_path, sequence)
      %w[logs inspection traces].each do |directory|
        import_evidence_directory(source, artifact_name, directory)
      end
    end

    manifest = read_json("manifest.json")
    manifest["evidence_sources"] = imported_artifacts
    write_json("manifest.json", manifest)

    puts "Merged evidence from #{imported_artifacts.length} worker artifact(s)"
    0
  end

  def verify_commands
    ensure_initialized
    failed = read_command_records.select { |record| record.fetch("status") == "failed" }
    return 0 if failed.empty?

    failed.each do |record|
      warn "Recorded check failed: #{record.fetch('name')} (exit #{record.fetch('exit_code')})"
    end
    1
  end

  def import_worker_manifest(source, artifact_name)
    path = File.join(source, "manifest.json")
    return unless File.file?(path)

    worker_directory = File.join(@evidence_dir, "workers")
    FileUtils.mkdir_p(worker_directory)
    destination = File.join(worker_directory, "#{artifact_name}.json")
    FileUtils.cp(path, destination)

    manifest = read_json("manifest.json")
    manifest["worker_runs"] ||= []
    worker_manifest = JSON.parse(File.read(path))
    manifest["worker_runs"] << {
      "artifact" => artifact_name,
      "workflow" => worker_manifest["workflow"],
      "commit" => worker_manifest["commit"],
      "pull_request" => worker_manifest["pull_request"]
    }
    write_json("manifest.json", manifest)
  end

  def import_command_records(source, artifact_name, records_path, sequence)
    source_records = File.join(source, "test-results", "commands.jsonl")
    return sequence unless File.file?(source_records)

    File.foreach(source_records) do |line|
      next if line.strip.empty?

      record = JSON.parse(line)
      source_log = File.expand_path(record.fetch("log"), source)
      source_prefix = "#{File.expand_path(source)}/"
      unless source_log.start_with?(source_prefix)
        raise "command log path escapes evidence artifact directory: #{record['log'].inspect}"
      end

      log_name = format("%03d-%s.log", sequence, record.fetch("name"))
      destination_log = File.join(@evidence_dir, "test-results", log_name)
      if File.file?(source_log)
        FileUtils.cp(source_log, destination_log)
      else
        File.write(destination_log, "Original command log is missing from artifact #{artifact_name}: #{record['log']}\n")
      end

      record["log"] = relative_path(destination_log)
      record["artifact"] = artifact_name
      File.open(records_path, "a") { |file| file.puts(JSON.generate(record)) }
      sequence += 1
    end

    sequence
  end

  def import_evidence_directory(source, artifact_name, directory)
    source_directory = File.join(source, directory)
    return unless File.directory?(source_directory)

    Dir.glob(File.join(source_directory, "**", "*"), File::FNM_DOTMATCH).each do |entry|
      next unless File.file?(entry)

      relative = entry.delete_prefix("#{source_directory}/")
      destination = File.join(@evidence_dir, directory, relative)
      FileUtils.mkdir_p(File.dirname(destination))

      if File.exist?(destination)
        next if FileUtils.compare_file(entry, destination)

        extension = File.extname(destination)
        basename = File.basename(destination, extension)
        destination = File.join(File.dirname(destination), "#{basename}-#{artifact_name}#{extension}")
      end

      FileUtils.cp(entry, destination)
    end
  end

  def finalize_evidence
    ensure_initialized
    records = read_command_records
    write_json("test-results/commands.json", records)

    manifest = read_json("manifest.json")
    manifest["finalized_at_utc"] = Time.now.utc.iso8601(6)
    manifest["environment"] = environment_details
    recorded_names = records.map { |record| record.fetch("name") }.uniq
    missing_checks = EXPECTED_CHECKS - recorded_names
    failed_count = records.count { |record| record.fetch("status") == "failed" }
    result = if missing_checks.any?
      "incomplete"
    elsif failed_count.positive?
      "failed"
    else
      "passed"
    end

    manifest["checks"] = {
      "total" => records.length,
      "passed" => records.count { |record| record.fetch("status") == "passed" },
      "failed" => failed_count,
      "missing" => missing_checks,
      "result" => result
    }
    write_json("manifest.json", manifest)
    write_summary(records, manifest)

    puts "Wrote #{relative_path(File.join(@evidence_dir, 'manifest.json'))}"
    puts "Wrote #{relative_path(File.join(@evidence_dir, 'review-summary.md'))}"
    result == "passed" ? 0 : 1
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
      table_row("Overall result", manifest.dig("checks", "result")&.upcase),
      "",
      "## Toolchain",
      "",
      "| Tool | Version |",
      "| --- | --- |",
      table_row("Crystal", manifest.dig("environment", "toolchain", "crystal")),
      table_row("Shards", manifest.dig("environment", "toolchain", "shards")),
      table_row("Ruby", manifest.dig("environment", "toolchain", "ruby")),
      table_row("Bundler", manifest.dig("environment", "toolchain", "bundler")),
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

    (manifest.dig("checks", "missing") || []).each do |name|
      lines << "| #{escape_table(name)} | NOT RUN | — | — | — | — |"
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
      "- `logs/`: captured Xvfb, LavinMQ, daemon stdout/stderr, X11 window snapshots, and process-table diagnostics.",
      "- `traces/daemon-lifecycle.jsonl`: timestamped scenario events and every observed framebuffer/spatial state.",
      "- `inspection/`: the PNG and OCR output produced by the inspector integration spec.",
      "",
      "## Interpretation",
      "",
      "A check is marked passed only when its command exited with status 0. Missing expected checks make the report incomplete. A green workflow is still required; this report does not replace CI status checks.",
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
