require "./xephyr.context/*"

VERSION = "0.0.0"

case ARGV.size
when 1
  case ARGV[0]
  when "-v", "version", "--version"
    puts VERSION
    exit
  when "-h", "help", "--help"
    print_help
    exit
  end
end

# Bindings to the native X11 C library
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

  fun x_open_display = XOpenDisplay(display_name : LibC::Char*) : Display
  fun x_close_display = XCloseDisplay(display : Display) : LibC::Int
  fun x_default_root_window = XDefaultRootWindow(display : Display) : Window
  
  fun x_query_tree = XQueryTree(
    display : Display, w : Window, root_return : Window*, parent_return : Window*,
    children_return : Window**, nchildren_return : LibC::UInt*
  ) : LibC::Int
  
  fun x_fetch_name = XFetchName(display : Display, w : Window, window_name_return : LibC::Char**) : LibC::Int
  fun x_free = XFree(data : Void*) : LibC::Int
  
  fun x_get_image = XGetImage(
    display : Display, d : Drawable, x : LibC::Int, y : LibC::Int,
    width : LibC::UInt, height : LibC::UInt, plane_mask : LibC::ULong, format : LibC::Int
  ) : XImage*
  
  fun x_destroy_image = XDestroyImage(image : XImage*) : LibC::Int
end

# Class to handle contextual scraping of a Xephyr/X11 instance
class XephyrContextAbsorber
  @display : LibX11::Display?
  @root_window : LibX11::Window?

  def initialize(@display_name : String = ":1")
  end

  # Establishes connection to the Xephyr X Server
  def connect
    @display = LibX11.x_open_display(@display_name.to_unsafe)
    if @display.nil?
      raise "Could not connect to Xephyr instance on display #{@display_name}. Is it running?"
    end
    @root_window = LibX11.x_default_root_window(@display.not_nil!)
    puts " Successfully bound to Xephyr display #{@display_name}"
  end

  # Scrapes all visible window text contexts and layout structures
  def absorb_window_tree
    display = @display.not_nil!
    root = @root_window.not_nil!

    root_return = uninitialized LibX11::Window
    parent_return = uninitialized LibX11::Window
    children_return = uninitialized LibX11::Window*
    nchildren = uninitialized LibC::UInt

    status = LibX11.x_query_tree(
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

    puts "\n--- Window Hierarchy Context (Total: #{nchildren}) ---"
    
    nchildren.times do |i|
      window_id = children_return[i]
      name_ptr = Pointer(LibC::Char).null
      
      # Extract text title context from the windows
      if LibX11.x_fetch_name(display, window_id, pointerof(name_ptr)) != 0
        window_title = String.new(name_ptr)
        puts "[Window ID: #{window_id}] Title: \"#{window_title}\""
        LibX11.x_free(name_ptr.as(Void*))
      else
        # Unnamed windows or basic containers
        puts "[Window ID: #{window_id}] Title: (No Name / Layout Container)"
      end
    end

    LibX11.x_free(children_return.as(Void*)) unless children_return.null?
  end

  # Samples raw visual frame buffer metadata from the Xephyr display
  def absorb_visual_metadata(width : Int32 = 100, height : Int32 = 100)
    display = @display.not_nil!
    root = @root_window.not_nil!
    
    # 2 means ZPixmap format (full color image format mapping)
    all_planes = ~0_u64 
    image_ptr = LibX11.x_get_image(display, root, 0, 0, width.to_u32, height.to_u32, all_planes, 2)
    
    if image_ptr.nil?
      puts "Could not capture image data context from root window."
      return
    end

    image = image_ptr.value
    puts "\n--- Visual Framebuffer Context ---"
    puts "Captured Top-Left Grid: #{image.width}x#{image.height}"
    puts "Depth color profile   : #{image.depth}-bit"
    puts "Bits per pixel        : #{image.bits_per_pixel} bpp"
    
    # Safely free XImage memory structures via X11 client tracking
    LibX11.x_destroy_image(image_ptr)
  end

  # Clean disconnect from X server
  def disconnect
    if disp = @display
      LibX11.x_close_display(disp)
      puts "\n Closed connection to Xephyr gracefully."
    end
  end
end

# Execution pipeline
begin
  # Target your running Xephyr display number (Usually :1, :2, etc.)
  target_display = ENV.fetch("DISPLAY_TARGET", ":1")
  
  absorber = XephyrContextAbsorber.new(target_display)
  absorber.connect
  
  # Absorb both text/structural hierarchy and raw visual metadata
  absorber.absorb_window_tree
  absorber.absorb_visual_metadata(800, 600)
  
ensure
  absorber.disconnect if absorber
end
