@[Link("X11")]
lib LibX11
  alias Window = LibC::ULong
  alias Drawable = LibC::ULong
  
  type Display = Void*
  type Visual = Void*
  
  # Event Mask Flags
  ExposureMask    = 1_i64 << 15
  StructureNotifyMask = 1_i64 << 17
  SubstructureNotifyMask = 1_i64 << 18
  
  # Event Codes
  Expose          = 12
  ConfigureNotify = 22
  
  struct XAnyEvent
    type : LibC::Int
    serial : LibC::ULong
    send_event : LibC::Int
    display : Display
    window : Window
  end
  
  struct XEvent
    type : LibC::Int
    pad : LibC::Long[24]
  end
  
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
  
  struct XWindowAttributes
    x : LibC::Int
    y : LibC::Int
    width : LibC::Int
    height : LibC::Int
    border_width : LibC::Int
    depth : LibC::Int
    visual : Void*
    root : Window
    class_enum : LibC::Int
    bit_gravity : LibC::Int
    win_gravity : LibC::Int
    backing_store : LibC::Int
    backing_planes : LibC::ULong
    backing_pixel : LibC::ULong
    save_under : LibC::Int       # Maps to C Bool (usually int)
    colormap : LibC::ULong       # Maps to Colormap XID
    map_installed : LibC::Int    # Maps to C Bool
    map_state : LibC::Int        # IsUnmapped, IsUnviewable, IsViewable
    all_event_masks : LibC::Long
    your_event_mask : LibC::Long
    do_not_propagate_mask : LibC::Long
    override_redirect : LibC::Int # Maps to C Bool
    screen : Void*               # Pointer to Screen structure
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
  
  # https://share.google/aimode/mVkJsTOuieeDT75rz
  fun XGetImage(
    display : Display, d : Drawable, x : LibC::Int, y : LibC::Int,
    width : LibC::UInt, height : LibC::UInt, plane_mask : LibC::ULong, format : LibC::Int
  ) : XImage*
  
  fun XDestroyImage(image : XImage*) : LibC::Int
  
  fun XGetWindowAttributes(display : Display, w : Window, attributes_return : XWindowAttributes*) : LibC::Int
  fun XSelectInput(display : Display, w : Window, event_mask : LibC::Long) : LibC::Int
  fun XNextEvent(display : Display, event_return : XEvent*) : LibC::Int
end