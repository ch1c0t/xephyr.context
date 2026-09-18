# Translates the elegant enum flags and registers them with the X Server
def select_input(types : X11::EventType)
  raw_mask = types.value.to_i64
  result = LibX11.XSelectInput(@display.handle, @id, raw_mask)

  if result == 0
    raise "Failed to register event configuration on Window #{@id}"
  end
end
