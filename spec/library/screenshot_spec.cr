require "spec"
require "random/secure"
require "../../src/screenshot"

describe Screenshot do
  it "saves a framebuffer as a PNG with the original dimensions" do
    pixels = Slice[
      0_u8, 0_u8, 255_u8, 255_u8,
      0_u8, 255_u8, 0_u8, 255_u8,
      255_u8, 0_u8, 0_u8, 255_u8,
      255_u8, 255_u8, 255_u8, 255_u8,
    ]
    state = XephyrContext::State.new(
      [] of JSON::Any,
      pixels,
      1_800_000_000_i64,
      2,
      2
    )
    directory = File.join(Dir.tempdir, "xephyr-context-#{Random::Secure.hex(8)}")

    begin
      Screenshot.new(state).save_to(directory)

      path = File.join(directory, "frame_1800000000.png")
      File.exists?(path).should be_true

      png = File.read(path).to_slice
      png[0, 8].should eq(Slice[137_u8, 80_u8, 78_u8, 71_u8, 13_u8, 10_u8, 26_u8, 10_u8])
      png[16, 4].to_a.should eq([0_u8, 0_u8, 0_u8, 2_u8])
      png[20, 4].to_a.should eq([0_u8, 0_u8, 0_u8, 2_u8])
    ensure
      FileUtils.rm_rf(directory)
    end
  end
end
