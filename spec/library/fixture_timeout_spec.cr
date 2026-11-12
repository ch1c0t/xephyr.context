require "spec"
require "./fixtures/xephyr_context"

describe "XephyrContextFixture state waiting" do
  it "includes the expectation and receive count when no states arrive" do
    fixture = XephyrContextFixture.new

    begin
      error = expect_raises(Exception) do
        fixture.receive_state_until("window title to disappear", 20.milliseconds) do
          false
        end
      end

      message = error.message || ""
      message.should contain("window title to disappear")
      message.should contain("Observed 0 canvas state(s)")
      message.should contain("No canvas states were received")
    ensure
      fixture.close
    end
  end

  it "includes the last state when no received state matches the expectation" do
    fixture = XephyrContextFixture.new

    begin
      fixture.subscribe
      fixture.publish_frame(
        Time.utc.to_unix,
        Bytes[0_u8, 0_u8, 0_u8, 255_u8],
        1,
        1
      )

      error = expect_raises(Exception) do
        fixture.receive_state_until("a window named READY", 100.milliseconds) do
          false
        end
      end

      message = error.message || ""
      message.should contain("Observed 1 canvas state(s)")
      message.should contain("Last state:")
      message.should contain("dimensions: 1x1")
      message.should contain("raw pixel bytes: 4")
      message.should contain("windows:")
    ensure
      fixture.close
    end
  end
end
