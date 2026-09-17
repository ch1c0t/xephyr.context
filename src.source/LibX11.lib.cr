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

# Structure representing layout positioning states in the X Server
struct XWindowAttributes
  x : LibC::Int
  y : LibC::Int
  width : LibC::Int
  height : LibC::Int
  border_width : LibC::Int
  depth : LibC::Int
  visual : Void*
  root : Window
  class_enum : LibC::Int # Is it InputOutput or InputOnly
  map_state : LibC::Int  # 0 = IsUnmapped, 1 = IsUnviewable, 2 = IsViewable
end

fun XGetWindowAttributes(display : Display, w : Window, attributes_return : XWindowAttributes*) : LibC::Int
