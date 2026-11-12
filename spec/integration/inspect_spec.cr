require "spec"
require "random/secure"
require "file_utils"
require "../library/fixtures/xephyr_context"
require "../library/fixtures/readiness_frame"

describe "xephyr.context.inspect executable" do
  it "replays a synthetic AMQP frame, saves a PNG, and writes OCR text" do
    socket = ENV["LAVINMQ_AMQP_UNIXSOCKET"]? ||
             raise "LAVINMQ_AMQP_UNIXSOCKET must point to a running LavinMQ UNIX socket"
    display = "spec-inspect-#{Process.pid}-#{Random::Secure.hex(6)}"
    fixture = XephyrContextFixture.new(display)
    directory = File.join("/tmp", "xephyr-inspect-#{Process.pid}-#{Random::Secure.hex(6)}")
    process : Process? = nil

    begin
      inspector = Process.new(
        "./bin/xephyr.context.inspect",
        ["--replay", "first", "--count", "1", "--ocr", "--save-dir", directory],
        env: {
          "DISPLAY_TARGET" => display,
          "LAVINMQ_AMQP_UNIXSOCKET" => socket,
        },
        output: Process::Redirect::Close,
        error: Process::Redirect::Close
      )

      process = inspector
      frame = ReadinessFrame.new
      fixture.publish_frame(Time.utc.to_unix, frame.pixels, frame.width, frame.height)

      status = inspector.wait
      status.success?.should be_true
      process = nil

      png_files = Dir.glob(File.join(directory, "*.png"))
      text_files = Dir.glob(File.join(directory, "*.txt"))
      png_files.size.should eq(1)
      text_files.size.should eq(1)
      File.read(text_files.first).upcase.should contain("READY")

      png = File.read(png_files.first).to_slice
      png[0, 8].should eq(Slice[137_u8, 80_u8, 78_u8, 71_u8, 13_u8, 10_u8, 26_u8, 10_u8])
      width = frame.width.to_u32
      png[16, 4].to_a.should eq([
        (width >> 24).to_u8,
        (width >> 16).to_u8,
        (width >> 8).to_u8,
        (width & 0xff).to_u8,
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
