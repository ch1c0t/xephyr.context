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

# Generic global pacing controller
def each(interval : Time::Span, &block)
  loop do
    yield
    sleep interval
  end
end

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
    context = absorber.absorb

    if canvas = context.canvas
      if canvas.changed?
        puts " [MUTATION] Pixels changed inside the sandbox!"
      else
        puts "No mutations"
      end
      canvas.destroy
    end
  end
ensure
  # 6. Gracefully tear down the X11 connection loop at the absolute end
  display.close
  puts "\n Closed connections to Xephyr gracefully."
end
