def each_event(
  types : X11::EventType = X11::EventType::Redraw | X11::EventType::LayoutChange | X11::EventType::ChildChange,
  &block : X11::Event ->
)
  subscribe_all(types)

  # 3. Allocate a single memory slot on the stack for incoming data
  raw_event = uninitialized LibX11::XEvent

  loop do
    # 4. BLOCKING CALL: Pause execution here until the server speaks
    LibX11.XNextEvent(@handle, pointerof(raw_event))

    # 5. Wrap the low-level struct in a beautiful object and pass it to the block
    yield X11::Event.new(raw_event)
  end
end
