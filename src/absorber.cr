class Absorber
  module Absorb
    # 💡 THINK: Captures everything on the display right now
    def absorb(width : Int32? = nil, height : Int32? = nil) : X11::Context
      root = @display.root_window
    
      if width.nil? || height.nil?
        res = @display.resolution
        width ||= res[:width]
        height ||= res[:height]
      end
    
      # Step 2: Build the structural data mapping array
      windows = fetch_window_list(root)
    
      # Step 3: Capture the physical frame snapshot map
      canvas = X11::Image.new(@display, root, width, height)
    
      # Return the clean, unified payload package
      X11::Context.new(windows, canvas)
    end
  end

  module FetchWindowList
    # 💡 THINK: Hidden pointer gymnastics cleanly boxed away
    private def fetch_window_list(root : LibX11::Window) : Array(X11::Window)
      root_ret = uninitialized LibX11::Window
      parent_ret = uninitialized LibX11::Window
      nchildren = uninitialized LibC::UInt
      children_ptr = uninitialized LibX11::Window*
    
      status = LibX11.XQueryTree(@display.handle, root, pointerof(root_ret), pointerof(parent_ret), pointerof(children_ptr), pointerof(nchildren))
    
      list = [] of X11::Window
    
      if status != 0 && !children_ptr.null?
        Slice.new(children_ptr, nchildren.to_i32).each do |id|
          list << X11::Window.new(id, @display)
        end
        LibX11.XFree(children_ptr.as(Void*)) # Burn C memory allocations immediately
      end
    
      list
    end
  end

  module Summarize
    def summarize : Nil
      context = absorb
      begin
        context.summarize
      ensure
        # Guaranteed execution block to ensure zero memory leaks
        context.canvas.try(&.destroy)
      end
    end
  end

  def initialize(@display : X11::Display)
  end
  
  include Absorb
  include Summarize
  include FetchWindowList
end