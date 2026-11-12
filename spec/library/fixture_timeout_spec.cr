require "spec"
require "./fixtures/xephyr_context"

describe "XephyrContextFixture state waiting" do
  it "includes the expectation and receive count when the wait times out" do
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
end
