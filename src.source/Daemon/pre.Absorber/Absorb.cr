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
