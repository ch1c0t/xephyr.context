# Bindings to the native X11 C library using original PascalCase names
@[Link("X11")]
lib LibX11
  alias Window = LibC::ULong
  alias Drawable = LibC::ULong
  type Display = Void*
  type Visual = Void*
  
  struct XImage
    width : LibC::Int
    height : LibC::Int
    xoffset : LibC::Int
    format : LibC::Int
    data : LibC::Char*
    byte_order : LibC::Int
    bitmap_unit : LibC::Int
    bitmap_bit_order : LibC::Int
    bitmap_pad : LibC::Int
    depth : LibC::Int
    bytes_per_line : LibC::Int
    bits_per_pixel : LibC::Int
    red_mask : LibC::ULong
    green_mask : LibC::ULong
    blue_mask : LibC::ULong
  end

  fun XOpenDisplay(display_name : LibC::Char*) : Display
  fun XCloseDisplay(display : Display) : LibC::Int
  fun XDefaultRootWindow(display : Display) : Window
  
  fun XQueryTree(
    display : Display, w : Window, root_return : Window*, parent_return : Window*,
    children_return : Window**, nchildren_return : LibC::UInt*
  ) : LibC::Int
  
  fun XFetchName(display : Display, w : Window, window_name_return : LibC::Char**) : LibC::Int
  fun XFree(data : Void*) : LibC::Int
  
  fun XGetImage(
    display : Display, d : Drawable, x : LibC::Int, y : LibC::Int,
    width : LibC::UInt, height : LibC::UInt, plane_mask : LibC::ULong, format : LibC::Int
  ) : XImage*
  
  fun XDestroyImage(image : XImage*) : LibC::Int
end

class XephyrContextAbsorber
  @display : LibX11::Display?
  @root_window : LibX11::Window?

  def initialize(@display_name : String = ":1")
  end

  def connect
    @display = LibX11.XOpenDisplay(@display_name.to_unsafe)
    if @display.nil?
      raise "Could not connect to Xephyr instance on display #{@display_name}. Is it running?"
    end
    @root_window = LibX11.XDefaultRootWindow(@display.not_nil!)
    puts " Successfully bound to Xephyr display #{@display_name}"
  end

  def absorb_window_tree
    display = @display.not_nil!
    root = @root_window.not_nil!

    root_return = uninitialized LibX11::Window
    parent_return = uninitialized LibX11::Window
    children_return = uninitialized LibX11::Window*
    nchildren = uninitialized LibC::UInt

    status = LibX11.XQueryTree(
      display, 
      root, 
      pointerof(root_return), 
      pointerof(parent_return), 
      pointerof(children_return), 
      pointerof(nchildren)
    )
    
    if status == 0
      puts "Failed to query the Xephyr window tree."
      return
    end

    total_children = nchildren.to_u32
    puts "\n--- Window Hierarchy Context (Total: #{total_children}) ---"
    
    total_children.times do |i|
      window_id = (children_return + i).value
      name_ptr = Pointer(LibC::Char).null
      
      if LibX11.XFetchName(display, window_id, pointerof(name_ptr)) != 0
        window_title = String.new(name_ptr)
        puts "[Window ID: #{window_id}] Title: \"#{window_title}\""
        LibX11.XFree(name_ptr.as(Void*))
      else
        puts "[Window ID: #{window_id}] Title: (No Name / Layout Container)"
      end
    end

    LibX11.XFree(children_return.as(Void*)) unless children_return.null?
  end

  def absorb_visual_metadata(width : Int32 = 100, height : Int32 = 100)
    display = @display.not_nil!
    root = @root_window.not_nil!
    
    all_planes = ~0_u64 
    
    # CRITICAL FIX: Explicitly cast the Window type into a Drawable type descriptor
    drawable_target = root.as(LibX11::Drawable)
    
    image_ptr = LibX11.XGetImage(display, drawable_target, 0, 0, width.to_u32, height.to_u32, all_planes, 2)
    
    if image_ptr.nil?
      puts "Could not capture image data context from root window."
      return
    end

    image = image_ptr.value
    puts "\n--- Visual Framebuffer Context ---"
    puts "Captured Top-Left Grid: #{image.width}x#{image.height}"
    puts "Depth color profile   : #{image.depth}-bit"
    puts "Bits per pixel        : #{image.bits_per_pixel} bpp"
    
    LibX11.XDestroyImage(image_ptr)
  end

  def disconnect
    if disp = @display
      LibX11.XCloseDisplay(disp)
      puts "\n Closed connection to Xephyr gracefully."
    end
  end
end

begin
  target_display = ENV.fetch("DISPLAY_TARGET", ":1")
  
  absorber = XephyrContextAbsorber.new(target_display)
  absorber.connect
  
  absorber.absorb_window_tree
  absorber.absorb_visual_metadata(800, 600)
ensure
  absorber.disconnect if absorber
end
