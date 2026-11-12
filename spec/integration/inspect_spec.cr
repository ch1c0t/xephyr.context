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
    evidence_root = ENV["REVIEW_EVIDENCE_DIR"]?
    preserve_evidence = !evidence_root.nil?
    directory = if root = evidence_root
      File.join(root, "inspection")
    else
      File.join("/tmp", "xephyr-inspect-#{Process.pid}-#{Random::Secure.hex(6)}")
    end
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
      recognized_text = File.read(text_files.first)
      recognized_text.upcase.should contain("READY")

      png = File.read(png_files.first).to_slice
      png[0, 8].should eq(Slice[137_u8, 80_u8, 78_u8, 71_u8, 13_u8, 10_u8, 26_u8, 10_u8])
      width = frame.width.to_u32
      height = frame.height.to_u32
      png[16, 4].to_a.should eq([
        (width >> 24).to_u8,
        (width >> 16).to_u8,
        (width >> 8).to_u8,
        (width & 0xff).to_u8,
      ])
      png[20, 4].to_a.should eq([
        (height >> 24).to_u8,
        (height >> 16).to_u8,
        (height >> 8).to_u8,
        (height & 0xff).to_u8,
      ])

      inspection_evidence = JSON.build do |json|
        json.object do
          json.field "display_target", display
          json.field "frame_width", frame.width
          json.field "frame_height", frame.height
          json.field "png", File.basename(png_files.first)
          json.field "ocr_text", File.basename(text_files.first)
          json.field "expected_text", "READY"
          json.field "recognized_text_contains_expected", recognized_text.upcase.includes?("READY")
        end
      end
      File.write(File.join(directory, "evidence.json"), inspection_evidence + "\n")
    ensure
      if running = process
        begin
          running.signal(Signal::TERM)
          running.wait
        rescue
        end
      end
      fixture.close
      FileUtils.rm_rf(directory) unless preserve_evidence
    end
  end
end
