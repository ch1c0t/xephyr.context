def each_event(
  mask : Int64 = X11::ALL_EVENTS_MASK,
  &block : X11::Event ->
)
  subscribe_all(mask)

  # 3. Allocate a single memory slot on the stack for incoming data
  raw_event = uninitialized LibX11::XEvent

  loop do
    # 4. BLOCKING CALL: Pause execution here until the server speaks
    LibX11.XNextEvent(@handle, pointerof(raw_event))

    # 5. Wrap the low-level struct in a beautiful object and pass it to the block
    yield X11::Event.new(raw_event)
  end
end
