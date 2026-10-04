# 💡 THINK: Hidden pointer gymnastics cleanly boxed away
private def fetch_window_list(root : LibX11::Window) : Array(X11::Window)
  root_ret = uninitialized LibX11::Window
  parent_ret = uninitialized LibX11::Window
  nchildren = uninitialized LibC::UInt
  children_ptr = uninitialized LibX11::Window*

  status = LibX11.XQueryTree(@display.handle, root, pointerof(root_ret), pointerof(parent_ret), pointerof(children_ptr), pointerof(nchildren))

  list = [] of X11::Window

  if status != 0 && !children_ptr.null?
    Slice.new(children_ptr, nchildren.to_i32).each do |id|
      list << X11::Window.new(id, @display)
    end
    LibX11.XFree(children_ptr.as(Void*)) # Burn C memory allocations immediately
  end

  list
end
