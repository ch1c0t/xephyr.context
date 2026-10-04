def initialize(@display_target : String = Global.display)
end

def run
  display = X11::Display.new(@display_target)

  begin
    absorber = Absorber.new(display)
    absorber.summarize

    publisher = Publisher.new

    each Global.interval do
      context = absorber.absorb
      canvas = context.canvas

      if canvas.changed?
        puts "[MUTATION] Pixels changed inside the sandbox!"
        publisher.call context
      else
        puts "No mutations"
      end

      canvas.destroy
    end
  ensure
    display.close
  end
end
