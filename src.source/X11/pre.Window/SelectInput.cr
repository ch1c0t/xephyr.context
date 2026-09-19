def select_input(mask : Int64 = X11::ALL_EVENTS_MASK)
  result = LibX11.XSelectInput(@display.handle, @id, mask)

  if result == 0
    raise "Failed to register event configuration on Window #{@id}"
  end
end
