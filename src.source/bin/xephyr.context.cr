require "../x11"
require "../absorber"

# 1. Initialize the display explicitly at the top level
display = X11::Display.new(ENV.fetch("DISPLAY_TARGET", ":10"))

begin
  # 2. Initialize the absorber with the active display object
  absorber = Absorber.new(display)
  absorber.summarize

  each 1000.milliseconds do
    pp! absorber
  end
ensure
  # 6. Gracefully tear down the X11 connection loop at the absolute end
  display.close
  puts "\n Closed connections to Xephyr gracefully."
end
