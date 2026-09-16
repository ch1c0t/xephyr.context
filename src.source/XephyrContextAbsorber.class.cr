@display : LibX11::Display
@root_window : LibX11::Window

def initialize(@display_name : String = ":1")
  # FIXED: Safely instantiate a null pointer matching the LibX11 wrapper type
  @display = Pointer(Void).null.as(LibX11::Display)
  @root_window = 0_u64.as(LibX11::Window)
end

def connect
  raw_display = LibX11.XOpenDisplay(@display_name.to_unsafe)
  
  # Check if the returned C pointer is null by converting back to Void*
  if raw_display.as(Void*).null?
    raise "Could not connect to Xephyr display #{@display_name}"
  end
  
  @display = raw_display
  @root_window = LibX11.XDefaultRootWindow(@display)
  puts " Successfully bound to Xephyr display #{@display_name}"
end

def absorb_window_tree
  # Local assignments let the compiler isolate these values for thread safety
  display_ctx = @display
  root_ctx = @root_window

  root_ret = uninitialized LibX11::Window
  parent_ret = uninitialized LibX11::Window
  nchildren = uninitialized LibC::UInt
  children_ptr = uninitialized LibX11::Window*

  status = LibX11.XQueryTree(
    display_ctx, 
    root_ctx, 
    pointerof(root_ret), 
    pointerof(parent_ret), 
    pointerof(children_ptr), 
    pointerof(nchildren)
  )
  return puts "Failed to query the Xephyr window tree." if status == 0

  window_ids = Slice.new(children_ptr, nchildren.to_i32)
  puts "\n--- Window Hierarchy Context (Total: #{window_ids.size}) ---"
  
  window_ids.each do |raw_id|
    window = X11::Window.new(raw_id, display_ctx)
    puts "[Window ID: #{window.id}] Title: \"#{window.title}\""
  end

  LibX11.XFree(children_ptr.as(Void*)) unless children_ptr.null?
end

def absorb_visual_metadata(width : Int32 = 800, height : Int32 = 600)
  all_planes = ~0_u64
  drawable = @root_window.as(LibX11::Drawable)
  
  image_ptr = LibX11.XGetImage(@display, drawable, 0, 0, width.to_u32, height.to_u32, all_planes, 2)
  return puts "Could not capture image data context." if image_ptr.nil?

  img = image_ptr.value
  puts "\n--- Visual Framebuffer Context ---"
  puts "Captured Top-Left Grid: #{img.width}x#{img.height}"
  puts "Depth color profile   : #{img.depth}-bit"
  
  LibX11.XDestroyImage(image_ptr)
end

def disconnect
  # FIXED: Safely evaluate pointer address using Void* mapping
  unless @display.as(Void*).null?
    LibX11.XCloseDisplay(@display)
    puts "\n Closed connection to Xephyr gracefully."
  end
end
