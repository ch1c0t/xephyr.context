require "./lib_x11"

module X11

  class Window
    getter id : LibX11::Window
    
    def initialize(@id : LibX11::Window, @display : LibX11::Display)
    end
    
    # Abstracts away name fetching, pointer checking, and memory cleanup
    def title : String
      name_ptr = Pointer(LibC::Char).null
      
      if LibX11.XFetchName(@display, @id, pointerof(name_ptr)) != 0
        title_str = String.new(name_ptr)
        LibX11.XFree(name_ptr.as(Void*)) # Clean up C allocation immediately
        return title_str
      end
    
      "Unnamed / Layout Container"
    end
  end
end