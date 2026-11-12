require "spec"
require "../library/fixtures/xephyr_context"

describe "xephyr.context executable" do
  it "publishes changed Xvfb frames and shuts down cleanly on SIGTERM" do
    display = ":99"
    socket = ENV["LAVINMQ_AMQP_UNIXSOCKET"]? ||
             raise "LAVINMQ_AMQP_UNIXSOCKET must point to a running LavinMQ UNIX socket"

    fixture = XephyrContextFixture.new(display)
    process : Process? = nil
    window_process : Process? = nil

    begin
      fixture.subscribe

      Process.run(
        "xsetroot",
        ["-solid", "#123456"],
        env: {"DISPLAY" => display},
        output: Process::Redirect::Close,
        error: Process::Redirect::Close
      ).success?.should be_true

      producer = Process.new(
        "./bin/xephyr.context",
        env: {
          "DISPLAY_TARGET" => display,
          "PULL_INTERVAL" => "50",
          "LAVINMQ_AMQP_UNIXSOCKET" => socket,
        },
        output: Process::Redirect::Close,
        error: Process::Redirect::Close
      )

      process = producer

      first = fixture.receive_state
      first.width.should eq(640)
      first.height.should eq(480)
      first.raw_pixels.size.should be >= 640 * 480 * 4

      # An unchanged framebuffer must not produce another stream entry.
      fixture.receive_state_or_nil(200.milliseconds).should be_nil

      window = Process.new(
        "xmessage",
        ["-title", "xephyr-context-integration-window", "visible window"],
        env: {"DISPLAY" => display},
        output: Process::Redirect::Close,
        error: Process::Redirect::Close
      )
      window_process = window
      window_title = "xephyr-context-integration-window"
      window_visible = false

      30.times do
        window_visible = Process.run(
          "xwininfo",
          ["-name", window_title],
          env: {"DISPLAY" => display},
          output: Process::Redirect::Close,
          error: Process::Redirect::Close
        ).success?
        break if window_visible
        sleep 50.milliseconds
      end

      window_visible.should be_true

      Process.run(
        "xsetroot",
        ["-solid", "#654321"],
        env: {"DISPLAY" => display},
        output: Process::Redirect::Close,
        error: Process::Redirect::Close
      ).success?.should be_true

      second = fixture.receive_state_until do |state|
        state.windows.any? { |item| item["title"].as_s == window_title }
      end
      second.timestamp.should be >= first.timestamp
      second.raw_pixels.to_a.should_not eq(first.raw_pixels.to_a)

      window.signal(Signal::TERM)
      window.wait
      window_process = nil

      window_gone = false
      30.times do
        window_gone = !Process.run(
          "xwininfo",
          ["-name", window_title],
          env: {"DISPLAY" => display},
          output: Process::Redirect::Close,
          error: Process::Redirect::Close
        ).success?
        break if window_gone
        sleep 50.milliseconds
      end

      window_gone.should be_true

      Process.run(
        "xsetroot",
        ["-solid", "#123456"],
        env: {"DISPLAY" => display},
        output: Process::Redirect::Close,
        error: Process::Redirect::Close
      ).success?.should be_true

      third = fixture.receive_state_until { |state| state.windows.empty? }
      third.windows.should be_empty

      producer.signal(Signal::TERM)
      producer.wait.success?.should be_true
      process = nil
    ensure
      if running = window_process
        begin
          running.signal(Signal::TERM)
          running.wait
        rescue
        end
      end
      if running = process
        begin
          running.signal(Signal::TERM)
          running.wait
        rescue
        end
      end
      fixture.close
    end
  end
end
