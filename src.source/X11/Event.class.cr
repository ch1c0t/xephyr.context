getter type : Int32

def initialize(@raw_event : LibX11::XEvent)
  @type = @raw_event.type
end

# High-level property exposing the target Window ID cleanly
def window_id : LibX11::Window
  # Reinterpret cast the memory address layout to pull out the unified header fields
  pointerof(@raw_event).as(LibX11::XAnyEvent*).value.window
end

def expose? : Bool
  @type == LibX11::Expose
end

def configure_notify? : Bool
  @type == LibX11::ConfigureNotify
end
