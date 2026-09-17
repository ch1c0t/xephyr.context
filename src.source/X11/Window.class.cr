getter id : LibX11::Window

def initialize(@id : LibX11::Window, @display : X11::Display)
end

# Abstracts away name fetching, pointer checking, and memory cleanup
def title : String
  name_ptr = Pointer(LibC::Char).null
  
  if LibX11.XFetchName(@display.handle, @id, pointerof(name_ptr)) != 0
    title_str = String.new(name_ptr)
    LibX11.XFree(name_ptr.as(Void*)) # Clean up C allocation immediately
    return title_str
  end

  "Unnamed / Layout Container"
end

# Grabs physical spatial information so the agent knows where to click
def geometry
  attrs = uninitialized LibX11::XWindowAttributes
  LibX11.XGetWindowAttributes(@display.handle, @id, pointerof(attrs))
  
  {
    x: attrs.x,
    y: attrs.y,
    width: attrs.width,
    height: attrs.height,
    visible: attrs.map_state == 2 # 2 means IsViewable on screen
  }
end
