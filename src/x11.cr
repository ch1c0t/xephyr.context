require "./lib_x11"
require "compress/deflate"

module X11
  # https://share.google/aimode/ve4pLYNnk1fbjQITm
  # https://maltsev.space/blog/011-practical-bitwise-tricks-in-everyday-code
  # https://share.google/aimode/dMymIVrGGWVlg3ZLE
  enum EventType : Int64
    KeyPressMask             = 1_i64 << 0
    KeyReleaseMask           = 1_i64 << 1
    ButtonPressMask          = 1_i64 << 2
    ButtonReleaseMask        = 1_i64 << 3
    PointerMotionMask        = 1_i64 << 6
    ExposureMask             = 1_i64 << 15
    StructureNotifyMask      = 1_i64 << 17
    SubstructureNotifyMask   = 1_i64 << 18
    SubstructureRedirectMask = 1_i64 << 19
    FocusChangeMask          = 1_i64 << 23
  end
  
  # =========================================================================
  # THE COMBINED CONSTANT: Merges every critical observation mask together
  # =========================================================================
  ALL_EVENTS_MASK = EventType::KeyPressMask.value             |
                    EventType::KeyReleaseMask.value           |
                    EventType::ButtonPressMask.value          |
                    EventType::ButtonReleaseMask.value        |
                    EventType::PointerMotionMask.value        |
                    EventType::ExposureMask.value             |
                    EventType::StructureNotifyMask.value      |
                    EventType::SubstructureNotifyMask.value   |
                    EventType::SubstructureRedirectMask.value |
                    EventType::FocusChangeMask.value

  class Context
    property windows : Array(X11::Window)
    property canvas : X11::Image
    
    def initialize(@windows, @canvas)
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
        mask : Int64 = X11::ALL_EVENTS_MASK,
        &block : X11::Event ->
      )
        subscribe_all(mask)
      
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
      private def subscribe_all(mask : Int64 = X11::ALL_EVENTS_MASK)
        # 1. Attach to the primary root window layout
        root_window_object.select_input(mask)
      
        # 2. Start a deep recursive dive down the entire window tree
        subscribe_recursive(root_window, mask)
      end
      
      # RECURSIVE ENGINE: Climbs all the way down the UI widget branches
      private def subscribe_recursive(window_id : LibX11::Window, mask : Int64 = X11::ALL_EVENTS_MASK,)
        root_ret = uninitialized LibX11::Window
        parent_ret = uninitialized LibX11::Window
        nchildren = uninitialized LibC::UInt
        children_ptr = uninitialized LibX11::Window*
      
        status = LibX11.XQueryTree(@handle, window_id, pointerof(root_ret), pointerof(parent_ret), pointerof(children_ptr), pointerof(nchildren))
      
        if status != 0 && !children_ptr.null?
          # Extract the elements safely into a local slice pointer loop
          window_ids = Slice.new(children_ptr, nchildren.to_i32)
      
          window_ids.each do |child_id|
            window = Window.new child_id, self
            window.select_input(mask)
      
            # B. RECURSE: Keep diving down into this child's nested structures!
            subscribe_recursive(child_id, mask)
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
    module Changed
      # Returns true if this newly captured canvas differs from the previous historical frame
      def changed? : Bool
        img = @pointer.value
      
        # ZERO-COPY MEMORY BRIDGE: Map the raw C heap array directly into a Crystal Slice
        buffer_size = img.bytes_per_line * img.height
        raw_slice = Slice.new(img.data.as(UInt8*), buffer_size)
      
        # Compute an ultra-fast hardware-accelerated block hash
        current_hash = raw_slice.hash
      
        if current_hash != @@last_hash
          @@last_hash = current_hash
          true
        else
          false
        end
      end
    end
  
    module ToDeflate
      # 💡 THINK: Squeezes raw framebuffer memory into a dense binary byte slice
      def to_deflate : Slice(UInt8)
        img = @pointer.value
        buffer_size = img.bytes_per_line * img.height
        raw_pixel_bytes = Slice.new(img.data.as(UInt8*), buffer_size)
      
        compressed_io = IO::Memory.new
      
        Compress::Deflate::Writer.open(compressed_io) do |deflate|
          deflate.write(raw_pixel_bytes)
        end
      
        compressed_io.to_slice
      end
    end
  
    # Expose the underlying C pointer so hashing engines can read it directly
    getter pointer : LibX11::XImage*
    
    # We use a class variable so successive image allocations can compare histories
    @@last_hash : UInt64 = 0_u64
    
    include Changed
    include ToDeflate
    
    def initialize(@display : X11::Display, target : LibX11::Window, width : Int32, height : Int32)
      all_planes = ~0_u64 # Binary mask to read all color bitplanes (R, G, B, Alpha)
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
    
    # Explicit RAII memory deallocation
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
      def select_input(mask : Int64 = X11::ALL_EVENTS_MASK)
        result = LibX11.XSelectInput(@display.handle, @id, mask)
      
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