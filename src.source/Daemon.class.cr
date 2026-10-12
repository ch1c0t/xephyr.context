def initialize(@display_target : String = Global.display)
end

def run
  Log.info { "Starting display capture display=#{@display_target}" }
  display = X11::Display.new(@display_target)

  begin
    absorber = Absorber.new(display)
    absorber.summarize

    publisher = Publisher.new

    each Global.interval do
      context = absorber.absorb
      canvas = context.canvas

      if canvas.changed?
        Log.debug { "[MUTATION] Pixels changed inside the sandbox!" }
        publisher.call context
      else
        Log.trace { "No mutations" }
      end

      canvas.destroy
    end
  ensure
    Log.info { "Closing display capture display=#{@display_target}" }
    display.close
  end
end
