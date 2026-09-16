require "../lib_x11"
require "../xephyr_context_absorber"

begin
  target_display = ENV.fetch("DISPLAY_TARGET", ":1")
  
  absorber = XephyrContextAbsorber.new(target_display)
  absorber.connect
  
  absorber.absorb_window_tree
  absorber.absorb_visual_metadata(800, 600)
ensure
  absorber.disconnect if absorber
end
