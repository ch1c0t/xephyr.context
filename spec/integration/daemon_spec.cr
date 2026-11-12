require "spec"
require "../library/fixtures/xephyr_context"

describe "xephyr.context executable" do
  it "publishes changed Xvfb frames and shuts down cleanly on SIGTERM" do
    display = ":99"
    socket = ENV["LAVINMQ_AMQP_UNIXSOCKET"]? ||
             raise "LAVINMQ_AMQP_UNIXSOCKET must point to a running LavinMQ UNIX socket"

    fixture = XephyrContextFixture.new(display)
    process : Process? = nil

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

      Process.run(
        "xsetroot",
        ["-solid", "#654321"],
        env: {"DISPLAY" => display},
        output: Process::Redirect::Close,
        error: Process::Redirect::Close
      ).success?.should be_true

      second = fixture.receive_state
      second.timestamp.should be >= first.timestamp
      second.raw_pixels.to_a.should_not eq(first.raw_pixels.to_a)

      producer.signal(Signal::TERM)
      producer.wait.success?.should be_true
      process = nil
    ensure
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
