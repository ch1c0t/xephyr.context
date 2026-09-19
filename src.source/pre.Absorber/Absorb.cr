def absorb(width : Int32? = nil, height : Int32? = nil) : X11::Context
  root = @display.root_window

  if width.nil? || height.nil?
    res = @display.resolution
    width ||= res[:width]
    height ||= res[:height]
  end

  root_ret = uninitialized LibX11::Window
  parent_ret = uninitialized LibX11::Window
  nchildren = uninitialized LibC::UInt
  children_ptr = uninitialized LibX11::Window*

  status = LibX11.XQueryTree(@display.handle, root, pointerof(root_ret), pointerof(parent_ret), pointerof(children_ptr), pointerof(nchildren))
  
  windows = [] of X11::Window
  if status != 0 && !children_ptr.null?
    Slice.new(children_ptr, nchildren.to_i32).each do |id|
      # Pass the global parent display handle straight into the window
      windows << X11::Window.new(id, @display)
    end
    LibX11.XFree(children_ptr.as(Void*))
  end

  canvas = X11::Image.new(@display, root, width, height)
  X11::Context.new(windows, canvas)
end
