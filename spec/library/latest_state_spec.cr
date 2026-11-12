require "spec"
require "./fixtures/xephyr_context"

describe "XephyrContext#latest_state" do
  it "is nil until the first canvas mutation is received" do
    fixture = XephyrContextFixture.new

    begin
      fixture.context.latest_state.should be_nil
    ensure
      fixture.close
    end
  end

  it "caches the newest state without changing mutation callbacks" do
    fixture = XephyrContextFixture.new

    begin
      first_pixels = Slice[0x10_u8, 0x20_u8, 0x30_u8, 0xff_u8,
                           0x40_u8, 0x50_u8, 0x60_u8, 0xff_u8]
      second_pixels = Slice[0x70_u8, 0x80_u8, 0x90_u8, 0xff_u8,
                            0xa0_u8, 0xb0_u8, 0xc0_u8, 0xff_u8]

      fixture.subscribe
      fixture.context.latest_state.should be_nil

      fixture.publish_frame(1_000_i64, first_pixels)
      first_state = fixture.receive_state

      first_state.timestamp.should eq(1_000_i64)
      first_state.width.should eq(2)
      first_state.height.should eq(1)
      first_state.raw_pixels.to_a.should eq(first_pixels.to_a)

      fixture.publish_frame(2_000_i64, second_pixels)
      second_state = fixture.receive_state

      second_state.timestamp.should eq(2_000_i64)
      second_state.width.should eq(2)
      second_state.height.should eq(1)
      second_state.raw_pixels.to_a.should eq(second_pixels.to_a)

      latest_state = fixture.context.latest_state
      latest_state.should_not be_nil
      latest_state = latest_state.not_nil!

      latest_state.timestamp.should eq(second_state.timestamp)
      latest_state.raw_pixels.to_a.should eq(second_pixels.to_a)
    ensure
      fixture.close
    end
  end

  it "includes the latest spatial metadata in the cached framebuffer state" do
    fixture = XephyrContextFixture.new

    begin
      windows = [
        JSON.parse(%({"id":42,"title":"terminal","spatial":{"x":12,"y":24,"width":320,"height":200,"visible":true}})),
      ]

      fixture.subscribe
      fixture.publish_spatial(windows)

      state = nil.as(XephyrContext::State?)
      20.times do |index|
        fixture.publish_frame(3_000_i64 + index, Slice[0x10_u8, 0x20_u8, 0x30_u8, 0xff_u8])
        candidate = fixture.receive_state

        if candidate.windows == windows
          state = candidate
          break
        end

        sleep 25.milliseconds
      end

      state.should_not be_nil
      latest_state = fixture.context.latest_state.not_nil!
      latest_state.windows.should eq(windows)
      latest_state.timestamp.should eq(state.not_nil!.timestamp)
    ensure
      fixture.close
    end
  end
end
