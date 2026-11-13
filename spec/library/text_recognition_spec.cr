require "spec"
require "./fixtures/xephyr_context"
require "./fixtures/readiness_frame"

describe "XephyrContext::TextRecognition" do
  it "recognizes a new framebuffer in the background and reuses its cached result" do
    fixture = XephyrContextFixture.new
    recognition = XephyrContext::TextRecognition.new(fixture.context)

    begin
      frame = ReadinessFrame.new
      timestamp = Time.utc.to_unix_ms
      fixture.publish_frame(timestamp, frame.pixels, frame.width, frame.height)

      result = recognition.wait_for_current_state(10.seconds)
      result.timestamp.should eq(timestamp)
      result.text.upcase.should contain("READY")
      result.success?.should be_true

      recognition.latest_for_current_state.not_nil!.same?(result).should be_true
      recognition.wait_for_current_state.same?(result).should be_true
    ensure
      recognition.close
      fixture.close
    end
  end

  it "shares the background recognizer with wait_until" do
    fixture = XephyrContextFixture.new
    recognition = XephyrContext::TextRecognition.new(fixture.context)

    begin
      frame = ReadinessFrame.new
      timestamp = Time.utc.to_unix_ms

      state = recognition.wait_until("ready", 10.seconds) do
        fixture.publish_frame(timestamp, frame.pixels, frame.width, frame.height)
      end

      state.timestamp.should eq(timestamp)
      result = recognition.latest_for_current_state
      result.should_not be_nil
      result = result.not_nil!
      result.timestamp.should eq(timestamp)
      result.text.downcase.should contain("ready")
    ensure
      recognition.close
      fixture.close
    end
  end

  it "unregisters its mutation callback and stops its worker on close" do
    fixture = XephyrContextFixture.new
    recognition = XephyrContext::TextRecognition.new(fixture.context)

    begin
      fixture.context.@mutation_callbacks.size.should eq(1)
      recognition.close
      fixture.context.@mutation_callbacks.should be_empty

      expect_raises(Exception, "Text recognition is closed") do
        recognition.wait_for_current_state
      end
    ensure
      recognition.close
      fixture.close
    end
  end
end
