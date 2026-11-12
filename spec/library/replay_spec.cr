require "spec"
require "./latest_state_fixture"

describe "XephyrContext#replay_mutations" do
  it "replays stored canvas mutations from the first stream entry by default" do
    fixture = LatestStateFixture.new

    begin
      first_pixels = Slice[0x10_u8, 0x20_u8, 0x30_u8, 0xff_u8]
      second_pixels = Slice[0x70_u8, 0x80_u8, 0x90_u8, 0xff_u8]

      fixture.publish_frame(1_000_i64, first_pixels)
      fixture.publish_frame(2_000_i64, second_pixels)

      replayed = Channel(XephyrContext::State).new(2)
      fixture.context.replay_mutations do |state|
        replayed.send(state)
      end

      first = fixture.receive_state_from(replayed)
      second = fixture.receive_state_from(replayed)

      first.timestamp.should eq(1_000_i64)
      first.raw_pixels.to_a.should eq(first_pixels.to_a)
      second.timestamp.should eq(2_000_i64)
      second.raw_pixels.to_a.should eq(second_pixels.to_a)
    ensure
      fixture.close
    end
  end

  it "cancels the replay consumer when the context is stopped" do
    fixture = LatestStateFixture.new

    begin
      first_pixels = Slice[0x10_u8, 0x20_u8, 0x30_u8, 0xff_u8]
      fixture.publish_frame(1_000_i64, first_pixels)

      replayed = Channel(XephyrContext::State).new(2)
      fixture.context.replay_mutations do |state|
        replayed.send(state)
      end
      first = fixture.receive_state_from(replayed)
      first.timestamp.should eq(1_000_i64)
      first.raw_pixels.to_a.should eq(first_pixels.to_a)

      fixture.context.stop
      fixture.publish_frame(
        2_000_i64,
        Slice[0x70_u8, 0x80_u8, 0x90_u8, 0xff_u8]
      )

      fixture.receive_state_from_or_nil(replayed, 200.milliseconds).should be_nil
    ensure
      fixture.close
    end
  end
end
