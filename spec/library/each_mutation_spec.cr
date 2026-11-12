require "spec"
require "./fixtures/xephyr_context"

describe "XephyrContext#each_mutation and #stop" do
  it "delivers every canvas mutation to each registered callback" do
    fixture = XephyrContextFixture.new

    begin
      first_callback = Channel(XephyrContext::State).new(2)
      second_callback = Channel(XephyrContext::State).new(2)

      fixture.subscribe { |state| first_callback.send(state) }
      fixture.subscribe { |state| second_callback.send(state) }

      first_pixels = Slice[0x10_u8, 0x20_u8, 0x30_u8, 0xff_u8]
      second_pixels = Slice[0x70_u8, 0x80_u8, 0x90_u8, 0xff_u8]

      fixture.publish_frame(1_000_i64, first_pixels)
      fixture.publish_frame(2_000_i64, second_pixels)

      first_states = Array(XephyrContext::State).new
      second_states = Array(XephyrContext::State).new

      2.times do
        first_states << fixture.receive_state_from(first_callback)
        second_states << fixture.receive_state_from(second_callback)
      end

      first_states.map(&.timestamp).should eq([1_000_i64, 2_000_i64])
      second_states.map(&.timestamp).should eq([1_000_i64, 2_000_i64])
      first_states.map { |state| state.raw_pixels.to_a }.should eq([
        first_pixels.to_a,
        second_pixels.to_a,
      ])
    ensure
      fixture.close
    end
  end

  it "emits an updated state when spatial metadata changes after the last canvas frame" do
    fixture = XephyrContextFixture.new

    begin
      callback = Channel(XephyrContext::State).new(2)
      fixture.subscribe { |state| callback.send(state) }

      pixels = Slice[0x10_u8, 0x20_u8, 0x30_u8, 0xff_u8]
      fixture.publish_frame(1_000_i64, pixels)
      first_state = fixture.receive_state_from(callback)

      first_state.windows.should be_empty
      first_state.raw_pixels.to_a.should eq(pixels.to_a)

      windows = [
        JSON.parse(%({"id":42,"title":"terminal","spatial":{"x":12,"y":24,"width":320,"height":200,"visible":true}})),
      ]
      fixture.publish_spatial(windows, 2_000_i64)

      updated_state = fixture.receive_state_from(callback)
      updated_state.timestamp.should eq(first_state.timestamp)
      updated_state.raw_pixels.to_a.should eq(first_state.raw_pixels.to_a)
      updated_state.windows.should eq(windows)

      latest_state = fixture.context.latest_state.not_nil!
      latest_state.timestamp.should eq(first_state.timestamp)
      latest_state.windows.should eq(windows)
    ensure
      fixture.close
    end
  end

  it "stops delivery and rejects new subscriptions after stop" do
    fixture = XephyrContextFixture.new

    begin
      fixture.subscribe
      fixture.context.stop
      fixture.context.stop

      error = expect_raises(Exception) do
        fixture.context.each_mutation { |_| }
      end
      error.message.should eq("XephyrContext is stopped")

      fixture.publish_frame(
        3_000_i64,
        Slice[0x10_u8, 0x20_u8, 0x30_u8, 0xff_u8]
      )

      fixture.receive_state_or_nil(200.milliseconds).should be_nil
    ensure
      fixture.close
    end
  end

  it "can be stopped before any consumer is started" do
    fixture = XephyrContextFixture.new

    begin
      fixture.context.stop
      fixture.context.stop

      expect_raises(Exception, "XephyrContext is stopped") do
        fixture.context.each_mutation { |_| }
      end
    ensure
      fixture.close
    end
  end
end
