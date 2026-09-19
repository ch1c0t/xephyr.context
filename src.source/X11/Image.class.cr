# Expose the underlying C pointer so hashing engines can read it directly
getter pointer : LibX11::XImage*

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
