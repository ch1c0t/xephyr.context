require "./lib_x11"

module X11
  # The @[Flags] annotation changes how this enum behaves under the hood
  # https://share.google/aimode/ve4pLYNnk1fbjQITm
  # https://maltsev.space/blog/011-practical-bitwise-tricks-in-everyday-code
  @[Flags]
  enum EventType : Int64
    Redraw       = 1_i64 << 15  # Maps to ExposureMask
    LayoutChange = 1_i64 << 17  # Maps to StructureNotifyMask
    ChildChange  = 1_i64 << 18  # Maps to SubstructureNotifyMask
  end

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
    module EachEvent
      def each_event(
        types : X11::EventType = X11::EventType::Redraw | X11::EventType::LayoutChange | X11::EventType::ChildChange,
        &block : X11::Event ->
      )
        subscribe_all(types)
      
        # 3. Allocate a single memory slot on the stack for incoming data
        raw_event = uninitialized LibX11::XEvent
      
        loop do
          # 4. BLOCKING CALL: Pause execution here until the server speaks
          LibX11.XNextEvent(@handle, pointerof(raw_event))
      
          # 5. Wrap the low-level struct in a beautiful object and pass it to the block
          yield X11::Event.new(raw_event)
        end
      end
    end
  
    module Resolution
      def resolution : NamedTuple(width: Int32, height: Int32)
        attrs = uninitialized LibX11::XWindowAttributes
        status = LibX11.XGetWindowAttributes(@handle, root_window, pointerof(attrs))
      
        if status == 0
          raise "Failed to query screen resolution attributes from the X11 root window"
        end
      
        {width: attrs.width, height: attrs.height}
      end
    end
  
    module RootWindow
      def root_window : LibX11::Window
        LibX11.XDefaultRootWindow(@handle)
      end
      
      def root_window_object : X11::Window
        X11::Window.new(root_window, self)
      end
    end
  
    module SubscribeAll
      # 💡 THINK: Hidden structural configuration helper
      private def subscribe_all(types : X11::EventType)
        # 1. Attach to the primary root window layout
        root_window_object.select_input(types)
      
        # 2. Start a deep recursive dive down the entire window tree
        subscribe_recursive(root_window, types)
      end
      
      # RECURSIVE ENGINE: Climbs all the way down the UI widget branches
      private def subscribe_recursive(window_id : LibX11::Window, types : X11::EventType)
        root_ret = uninitialized LibX11::Window
        parent_ret = uninitialized LibX11::Window
        nchildren = uninitialized LibC::UInt
        children_ptr = uninitialized LibX11::Window*
      
        status = LibX11.XQueryTree(@handle, window_id, pointerof(root_ret), pointerof(parent_ret), pointerof(children_ptr), pointerof(nchildren))
      
        if status != 0 && !children_ptr.null?
          # Extract the elements safely into a local slice pointer loop
          window_ids = Slice.new(children_ptr, nchildren.to_i32)
      
          window_ids.each do |child_id|
            # A. Hook this specific sub-component element window handle
            LibX11.XSelectInput(@handle, child_id, types.value.to_i64)
      
            # B. RECURSE: Keep diving down into this child's nested structures!
            subscribe_recursive(child_id, types)
          end
      
          LibX11.XFree(children_ptr.as(Void*))
        end
      end
    end
  
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
    include SubscribeAll
    include EachEvent
  end

  class Event
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
    module Getters
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
  
    module SelectInput
      # Translates the elegant enum flags and registers them with the X Server
      def select_input(types : X11::EventType)
        raw_mask = types.value.to_i64
        result = LibX11.XSelectInput(@display.handle, @id, raw_mask)
      
        if result == 0
          raise "Failed to register event configuration on Window #{@id}"
        end
      end
    end
  
    getter id : LibX11::Window
    
    def initialize(@id : LibX11::Window, @display : X11::Display)
    end
    
    include Getters
    include SelectInput
  end
end