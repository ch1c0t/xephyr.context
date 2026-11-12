require "spec"
require "./fixtures/xephyr_context"
require "./fixtures/readiness_frame"

describe "XephyrContext#wait_until" do
  it "times out without initializing OCR when no canvas mutation arrives" do
    fixture = XephyrContextFixture.new

    begin
      triggered = false

      error = expect_raises(Exception, "Timed out waiting for \"READY\"") do
        fixture.context.wait_until("READY", 50.milliseconds) do
          triggered = true
        end
      end

      error.message.should eq("Timed out waiting for \"READY\"")
      triggered.should be_true
      fixture.context.@mutation_callbacks.should be_empty
      fixture.context.latest_state.should be_nil
    ensure
      fixture.close
    end
  end

  it "returns the frame whose recognized text matches without case sensitivity" do
    fixture = XephyrContextFixture.new

    begin
      frame = ReadinessFrame.new
      timestamp = Time.utc.to_unix_ms

      state = fixture.context.wait_until("ready", 10.seconds) do
        fixture.publish_frame(timestamp, frame.pixels, frame.width, frame.height)
      end

      state.timestamp.should eq(timestamp)
      state.width.should eq(frame.width)
      state.height.should eq(frame.height)
      state.raw_pixels.to_a.should eq(frame.pixels.to_a)
    ensure
      fixture.close
    end
  end

  it "can be used again after a previous wait times out" do
    fixture = XephyrContextFixture.new

    begin
      expect_raises(Exception, "Timed out waiting for \"READY\"") do
        fixture.context.wait_until("READY", 25.milliseconds)
      end

      frame = ReadinessFrame.new
      timestamp = Time.utc.to_unix_ms
      state = fixture.context.wait_until("READY", 10.seconds) do
        fixture.publish_frame(timestamp, frame.pixels, frame.width, frame.height)
      end

      state.timestamp.should eq(timestamp)
      fixture.context.@mutation_callbacks.should be_empty
    ensure
      fixture.close
    end
  end
end
