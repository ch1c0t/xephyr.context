require "../x11"
require "../xephyr_context_absorber"

# 1. Initialize the display explicitly at the top level
display = X11::Display.new(ENV.fetch("DISPLAY_TARGET", ":10"))

begin
  # 2. Initialize the absorber with the active display object
  absorber = XephyrContextAbsorber.new(display)
  
  # 3. Pull out the text and visual structural context snapshots
  context_payload = absorber.absorb(800, 600)
  
  # 4. Read titles safely while the display channel is active
  context_payload.summarize
  
  # 5. Destroy raw image allocation maps cleanly
  if canvas_img = context_payload.canvas
    canvas_img.destroy
  end
ensure
  # 6. Gracefully tear down the X11 connection loop at the absolute end
  display.close
end
