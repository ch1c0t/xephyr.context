require "../global"
require "../x11"
require "../absorber"
require "../publisher"

# 1. Initialize the display explicitly at the top level
display = X11::Display.new(Global.display)

begin
  absorber = Absorber.new(display)
  absorber.summarize

  publish = Publisher.new

  each 1000.milliseconds do
    context = absorber.absorb
    canvas = context.canvas

    if canvas.changed?
      puts "[MUTATION] Pixels changed inside the sandbox!"
      publish.call context
    else
      puts "No mutations"
    end

    canvas.destroy
  end
ensure
  # 6. Gracefully tear down the X11 connection loop at the absolute end
  display.close
  puts "\n Closed connections to Xephyr gracefully."
end
