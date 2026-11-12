require "spec"
require "../../src/xephyr_context"

describe "XephyrContext::ScreenRegion" do
  it "provides normalized named regions" do
    region = XephyrContext::ScreenRegion.third_quadrant

    region.x.should eq(0.0)
    region.y.should eq(0.5)
    region.width.should eq(0.5)
    region.height.should eq(0.5)
  end

  it "resolves regions from symbols" do
    XephyrContext::ScreenRegion.from_symbol(:bottom_tenth).should eq(
      XephyrContext::ScreenRegion.bottom_tenth
    )
  end

  it "rejects origins outside the screen" do
    expect_raises(Exception, "Region origin must be within 0.0..1.0") do
      XephyrContext::ScreenRegion.new(-0.1, 0.0, 0.5, 0.5)
    end
  end

  it "rejects regions that extend beyond the screen" do
    expect_raises(Exception, "Region must fit within the screen") do
      XephyrContext::ScreenRegion.new(0.75, 0.0, 0.5, 0.5)
    end
  end
end
