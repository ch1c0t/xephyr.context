def resolution : NamedTuple(width: Int32, height: Int32)
  attrs = uninitialized LibX11::XWindowAttributes
  status = LibX11.XGetWindowAttributes(@handle, root_window, pointerof(attrs))

  if status == 0
    raise "Failed to query screen resolution attributes from the X11 root window"
  end

  {width: attrs.width, height: attrs.height}
end
