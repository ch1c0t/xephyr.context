# 💡 THINK: Hidden structural configuration helper
private def subscribe_all(types : X11::EventType)
  # Hook the root layout canvas channel
  root_window_object.select_input(types)

  # Hook all current application container children running on the display
  # (This encapsulates the raw XQueryTree pointer gymnastics completely out of sight)
  query_tree_children.each do |child_id|
    LibX11.XSelectInput(@handle, child_id, types.value.to_i64)
  end
end

# Abstracted tree payload collector returning a clean Crystal array
private def query_tree_children : Array(LibX11::Window)
  root_ret = uninitialized LibX11::Window
  parent_ret = uninitialized LibX11::Window
  nchildren = uninitialized LibC::UInt
  children_ptr = uninitialized LibX11::Window*

  status = LibX11.XQueryTree(@handle, root_window, pointerof(root_ret), pointerof(parent_ret), pointerof(children_ptr), pointerof(nchildren))

  list = [] of LibX11::Window
  if status != 0 && !children_ptr.null?
    Slice.new(children_ptr, nchildren.to_i32).each { |id| list << id }
    LibX11.XFree(children_ptr.as(Void*))
  end
  list
end
