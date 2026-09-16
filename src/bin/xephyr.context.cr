require "./xephyr.context/*"

VERSION = "0.0.0"

case ARGV.size
when 1
  case ARGV[0]
  when "-v", "version", "--version"
    puts VERSION
    exit
  when "-h", "help", "--help"
    print_help
    exit
  end
end

require "../x11"
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
