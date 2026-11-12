def initialize(@display_target : String = Global.display)
end

def run
  Log.info { "Starting display capture display=#{@display_target}" }
  display = X11::Display.new(@display_target)

  running = true
  Signal::INT.trap { running = false }
  Signal::TERM.trap { running = false }

  begin
    absorber = Absorber.new(display)
    absorber.summarize

    publisher = Publisher.new

    while running
      context = absorber.absorb
      canvas = context.canvas

      begin
        if canvas.changed?
          Log.debug { "[MUTATION] Pixels changed inside the sandbox!" }
          publisher.call context
        else
          Log.trace { "No mutations" }
        end
      ensure
        canvas.destroy
      end

      sleep Global.interval
    end
  ensure
    Log.info { "Closing display capture display=#{@display_target}" }
    display.close
  end
end
