require "spec"
require "file_utils"
require "json"
require "../library/fixtures/xephyr_context"

class DaemonLifecycleTrace
  def initialize(@path : String)
    FileUtils.mkdir_p(File.dirname(@path))
    File.write(@path, "")
  end

  def record(
    event : String,
    details : String? = nil,
    state : XephyrContext::State? = nil
  ) : Nil
    payload = JSON.build do |json|
      json.object do
        json.field "at_utc", Time.utc.to_s
        json.field "event", event
        json.field "details", details if details

        if state
          json.field "state" do
            json.object do
              json.field "timestamp", state.timestamp
              json.field "width", state.width
              json.field "height", state.height
              json.field "raw_pixel_bytes", state.raw_pixels.size
              json.field "raw_pixel_hash", state.raw_pixels.hash.to_s
              json.field "windows", state.windows
            end
          end
        end
      end
    end

    File.open(@path, "a") { |file| file.puts(payload) }
  end
end

private def x11_window_snapshot(display : String, title : String)
  output = IO::Memory.new
  error = IO::Memory.new
  status = Process.run(
    "xwininfo",
    ["-name", title],
    env: {"DISPLAY" => display},
    output: output,
    error: error
  )

  {
    success: status.success?,
    stdout: output.to_s,
    stderr: error.to_s,
  }
end

private def set_root_background(display : String, color : String, phase : String) : Process::Status
  stdout = IO::Memory.new
  stderr = IO::Memory.new

  status = Process.run(
    "xsetroot",
    ["-solid", color],
    env: {"DISPLAY" => display},
    output: stdout,
    error: stderr
  )

  return status if status.success?

  message = String.build do |io|
    io << "Failed to set X11 root background during " << phase
    io << "\n  display: " << display
    io << "\n  command: xsetroot -solid " << color.inspect
    io << "\n  exit code: " << (status.exit_code?.try(&.to_s) || "terminated by signal")
    io << "\n  stdout:\n" << stdout.to_s
    io << "\n  stderr:\n" << stderr.to_s
  end

  raise message
end

private def record_x11_probe(
  trace : DaemonLifecycleTrace,
  snapshots_path : String,
  phase : String,
  snapshot
) : Nil
  details = String.build do |io|
    io << "success=" << snapshot[:success]
    io << "\nstdout:\n" << snapshot[:stdout]
    io << "\nstderr:\n" << snapshot[:stderr]
  end

  trace.record("x11_window_probe", "#{phase}\n#{details}")
  File.open(snapshots_path, "a") do |file|
    file << "\n=== " << phase << " ===\n"
    file << details << "\n"
  end
end

describe "xephyr.context executable" do
  it "publishes changed Xvfb frames and shuts down cleanly on SIGTERM" do
    display = ENV["XEPHYR_CONTEXT_TEST_DISPLAY"]? ||
               raise "XEPHYR_CONTEXT_TEST_DISPLAY must name the Xvfb display allocated for integration specs"
    display_number = display.match(/\A:(\d+)\z/).try { |match| match[1].to_i? }
    unless display_number && display_number >= 1000
      raise "XEPHYR_CONTEXT_TEST_DISPLAY must be a display number at or above :1000 (got #{display.inspect})"
    end
    socket = ENV["LAVINMQ_AMQP_UNIXSOCKET"]? ||
             raise "LAVINMQ_AMQP_UNIXSOCKET must point to a running LavinMQ UNIX socket"

    evidence_root = ENV["REVIEW_EVIDENCE_DIR"]? ||
                    File.join("/tmp", "xephyr-review-evidence-#{Process.pid}")
    logs_directory = File.join(evidence_root, "logs")
    traces_directory = File.join(evidence_root, "traces")
    FileUtils.mkdir_p(logs_directory)
    FileUtils.mkdir_p(traces_directory)

    daemon_log_path = File.join(logs_directory, "xephyr.context-daemon.log")
    x11_snapshots_path = File.join(logs_directory, "x11-window-snapshots.log")
    trace = DaemonLifecycleTrace.new(File.join(traces_directory, "daemon-lifecycle.jsonl"))
    File.write(x11_snapshots_path, "")

    fixture = XephyrContextFixture.new(display)
    process : Process? = nil
    window_process : Process? = nil
    daemon_log : File? = nil

    begin
      trace.record("fixture_connected", "display=#{display}")
      fixture.subscribe
      trace.record("state_subscription_started")

      initial_background = set_root_background(display, "#123456", "initial setup")
      trace.record("initial_background_set", "success=#{initial_background.success?}")

      daemon_log = File.open(daemon_log_path, "w")
      producer = Process.new(
        "./bin/xephyr.context",
        env: {
          "DISPLAY_TARGET" => display,
          "PULL_INTERVAL" => "50",
          "LAVINMQ_AMQP_UNIXSOCKET" => socket,
          "XEPHYR_LOG_LEVEL" => "TRACE",
        },
        output: daemon_log.not_nil!,
        error: daemon_log.not_nil!
      )

      process = producer
      trace.record("producer_started", "pid=#{producer.pid}; log=#{daemon_log_path}")

      first = fixture.receive_state
      trace.record("initial_frame_received", "first_frame", first)
      first.width.should eq(640)
      first.height.should eq(480)
      first.raw_pixels.size.should be >= 640 * 480 * 4

      # An unchanged framebuffer must not produce another stream entry.
      unchanged = fixture.receive_state_or_nil(200.milliseconds)
      trace.record("unchanged_frame_check", unchanged ? "unexpected state received" : "no state received, as expected", unchanged)
      unchanged.should be_nil

      window_title = "xephyr-context-integration-window"
      window = Process.new(
        "xmessage",
        ["-title", window_title, "visible window"],
        env: {"DISPLAY" => display},
        output: Process::Redirect::Close,
        error: Process::Redirect::Close
      )
      window_process = window
      trace.record("window_process_started", "pid=#{window.pid}; title=#{window_title}")

      window_snapshot = x11_window_snapshot(display, window_title)
      window_visible = window_snapshot[:success]
      record_x11_probe(trace, x11_snapshots_path, "window creation", window_snapshot)

      30.times do
        break if window_visible
        sleep 50.milliseconds
        window_snapshot = x11_window_snapshot(display, window_title)
        window_visible = window_snapshot[:success]
      end

      record_x11_probe(trace, x11_snapshots_path, "window creation final check", window_snapshot)
      window_visible.should be_true

      changed_background = set_root_background(display, "#654321", "while the window is open")
      trace.record("background_changed_with_window_open", "success=#{changed_background.success?}")

      second = fixture.receive_state_until("window title appears in spatial metadata") do |state|
        state.windows.any? { |item| item["title"].as_s == window_title }
      end
      trace.record("window_visible_in_state", "expected title found", second)
      second.timestamp.should be >= first.timestamp
      second.raw_pixels.to_a.should_not eq(first.raw_pixels.to_a)

      window.signal(Signal::TERM)
      window_status = window.wait
      window_process = nil
      trace.record("window_process_terminated", "success=#{window_status.success?}; exit_code=#{window_status.exit_code?}")

      window_snapshot = x11_window_snapshot(display, window_title)
      window_gone = !window_snapshot[:success]
      record_x11_probe(trace, x11_snapshots_path, "window destruction", window_snapshot)

      30.times do
        break if window_gone
        sleep 50.milliseconds
        window_snapshot = x11_window_snapshot(display, window_title)
        window_gone = !window_snapshot[:success]
      end

      record_x11_probe(trace, x11_snapshots_path, "window destruction final check", window_snapshot)
      window_gone.should be_true

      restored_background = set_root_background(display, "#123456", "after the window closes")
      trace.record("background_changed_after_window_close", "success=#{restored_background.success?}")

      third = fixture.receive_state_until("window title absent from spatial metadata") do |state|
        state.windows.none? { |item| item["title"]?.try(&.as_s) == window_title }
      end
      trace.record("window_absent_from_state", "target title absent", third)
      third.windows.none? { |item| item["title"]?.try(&.as_s) == window_title }.should be_true

      producer.signal(Signal::TERM)
      trace.record("producer_sigterm_sent", "pid=#{producer.pid}")
      producer_status = producer.wait
      trace.record("producer_exited", "success=#{producer_status.success?}; exit_code=#{producer_status.exit_code?}")
      producer_status.success?.should be_true
      process = nil
    rescue ex : Exception
      trace.record("scenario_error", "#{ex.class}: #{ex.message}")
      raise ex
    ensure
      if running = window_process
        begin
          trace.record("cleanup_window_process", "pid=#{running.pid}")
          running.signal(Signal::TERM)
          window_status = running.wait
          trace.record("cleanup_window_process_exited", "success=#{window_status.success?}; exit_code=#{window_status.exit_code?}")
        rescue ex : Exception
          trace.record("cleanup_window_process_error", "#{ex.class}: #{ex.message}")
        end
      end

      if running = process
        begin
          trace.record("cleanup_producer_process", "pid=#{running.pid}")
          running.signal(Signal::TERM)
          producer_status = running.wait
          trace.record("cleanup_producer_process_exited", "success=#{producer_status.success?}; exit_code=#{producer_status.exit_code?}")
        rescue ex : Exception
          trace.record("cleanup_producer_process_error", "#{ex.class}: #{ex.message}")
        end
      end

      daemon_log.try(&.close)
      trace.record("fixture_cleanup")
      fixture.close
    end
  end
end
