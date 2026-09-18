getter handle : LibX11::Display

def initialize(display_name : String)
  raw_display = LibX11.XOpenDisplay(display_name.to_unsafe)
  if raw_display.as(Void*).null?
    raise "Could not connect to X11 display #{display_name}"
  end
  @handle = raw_display
end

def close
  LibX11.XCloseDisplay(@handle)
end

include RootWindow
include Resolution
include EachEvent
