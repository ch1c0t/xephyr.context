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
