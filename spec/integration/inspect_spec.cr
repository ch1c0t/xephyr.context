require "spec"
require "random/secure"
require "../library/fixtures/xephyr_context"
require "../library/fixtures/readiness_frame"

describe "xephyr.context.inspect executable" do
  it "replays a synthetic AMQP frame, saves a PNG, and writes OCR text" do
    socket = ENV["LAVINMQ_AMQP_UNIXSOCKET"]? ||
             raise "LAVINMQ_AMQP_UNIXSOCKET must point to a running LavinMQ UNIX socket"
    display = "spec-inspect-#{Process.pid}-#{Random::Secure.hex(6)}"
    fixture = XephyrContextFixture.new(display)
    directory = File.join("/tmp", "xephyr-inspect-#{Process.pid}-#{Random::Secure.hex(6)}")
    process : Process?

    begin
      process = Process.new(
        "./bin/xephyr.context.inspect",
        ["--replay", "first", "--count", "1", "--ocr", "--save-dir", directory],
        env: {
          "DISPLAY_TARGET" => display,
          "LAVINMQ_AMQP_UNIXSOCKET" => socket,
        },
        output: Process::Redirect::Close,
        error: Process::Redirect::Close
      )

      frame = ReadinessFrame.new
      fixture.publish_frame(Time.utc.to_unix, frame.pixels, frame.width, frame.height)

      status = process.wait
      status.success?.should be_true
      process = nil

      image_path = File.join(directory, "frame_#{Time.utc.to_unix}.png")
      # The producer timestamp is captured once below in the filename assertion.
      png_files = Dir.glob(File.join(directory, "*.png"))
      text_files = Dir.glob(File.join(directory, "*.txt"))
      png_files.size.should eq(1)
      text_files.size.should eq(1)
      File.read(text_files.first).upcase.should contain("READY")

      png = File.read(png_files.first).to_slice
      png[0, 8].should eq(Slice[137_u8, 80_u8, 78_u8, 71_u8, 13_u8, 10_u8, 26_u8, 10_u8])
      png[16, 4].to_a.should eq([
        (frame.width >> 24).to_u8,
        (frame.width >> 16).to_u8,
        (frame.width >> 8).to_u8,
        frame.width.to_u8,
      ])
    ensure
      if running = process
        begin
          running.signal(Signal::TERM)
          running.wait
        rescue
        end
      end
      fixture.close
      FileUtils.rm_rf(directory)
    end
  end
end
