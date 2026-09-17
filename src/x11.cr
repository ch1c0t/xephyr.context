require "./lib_x11"

module X11

  class Context
    property windows : Array(X11::Window)
    property canvas : X11::Image?
    
    def initialize(@windows, @canvas = nil)
    end
    
    def summarize
      puts "\n--- Context Summary Payload ---"
      puts "Total Windows Found: #{@windows.size}"
      @windows.each_with_index do |win, i|
        puts "  [#{i}] ID: #{win.id} | Title: \"#{win.title}\""
      end
    
      if img = @canvas
        puts "Canvas Profile: #{img.width}x#{img.height} @ #{img.color_depth}-bit depth"
      end
    end
  end

  class Display
    getter handle : LibX11::Display
    
    def initialize(display_name : String)
      raw_display = LibX11.XOpenDisplay(display_name.to_unsafe)
      if raw_display.as(Void*).null?
        raise "Could not connect to X11 display #{display_name}"
      end
      @handle = raw_display
    end
    
    def root_window : LibX11::Window
      LibX11.XDefaultRootWindow(@handle)
    end
    
    def close
      LibX11.XCloseDisplay(@handle)
    end
  end

  class Image
    def initialize(@display : X11::Display, target : LibX11::Window, width : Int32, height : Int32)
      all_planes = ~0_u64
      drawable = target.as(LibX11::Drawable)
      
      @pointer = LibX11.XGetImage(@display.handle, drawable, 0, 0, width.to_u32, height.to_u32, all_planes, 2)
      raise "Failed to capture visual frame buffer pointer" if @pointer.nil?
    end
    
    def width : Int32
      @pointer.value.width
    end
    
    def height : Int32
      @pointer.value.height
    end
    
    def color_depth : Int32
      @pointer.value.depth
    end
    
    def destroy
      LibX11.XDestroyImage(@pointer) unless @pointer.nil?
    end
  end

  class Window
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
  end
end