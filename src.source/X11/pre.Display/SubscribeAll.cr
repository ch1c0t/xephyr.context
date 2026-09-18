# 💡 THINK: Hidden structural configuration helper
private def subscribe_all(types : X11::EventType)
  # 1. Attach to the primary root window layout
  root_window_object.select_input(types)

  # 2. Start a deep recursive dive down the entire window tree
  subscribe_recursive(root_window, types)
end

# RECURSIVE ENGINE: Climbs all the way down the UI widget branches
private def subscribe_recursive(window_id : LibX11::Window, types : X11::EventType)
  root_ret = uninitialized LibX11::Window
  parent_ret = uninitialized LibX11::Window
  nchildren = uninitialized LibC::UInt
  children_ptr = uninitialized LibX11::Window*

  status = LibX11.XQueryTree(@handle, window_id, pointerof(root_ret), pointerof(parent_ret), pointerof(children_ptr), pointerof(nchildren))

  if status != 0 && !children_ptr.null?
    # Extract the elements safely into a local slice pointer loop
    window_ids = Slice.new(children_ptr, nchildren.to_i32)

    window_ids.each do |child_id|
      # A. Hook this specific sub-component element window handle
      LibX11.XSelectInput(@handle, child_id, types.value.to_i64)

      # B. RECURSE: Keep diving down into this child's nested structures!
      subscribe_recursive(child_id, types)
    end

    LibX11.XFree(children_ptr.as(Void*))
  end
end
