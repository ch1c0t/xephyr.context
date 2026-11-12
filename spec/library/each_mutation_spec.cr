require "spec"
require "./latest_state_fixture"

describe "XephyrContext#each_mutation and #stop" do
  it "delivers every canvas mutation to each registered callback" do
    fixture = LatestStateFixture.new

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

  it "stops delivery and rejects new subscriptions after stop" do
    fixture = LatestStateFixture.new

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
    fixture = LatestStateFixture.new

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
