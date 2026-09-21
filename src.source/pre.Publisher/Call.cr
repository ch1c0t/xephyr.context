def call(context : X11::Context) : Nil
  # 1. Visual data pipeline execution pass
  canvas_json = serialize_canvas(context.canvas)
  @canvas_queue.publish(canvas_json)

  # 2. Dynamic telemetry initialization pass
  telemetry = Telemetry.new(context.windows, @spatial_queue.name)

  # 💡 PURE ENCAPSULATION: The queue manages its own socket delivery payload!
  if telemetry.changed?
    @spatial_queue.publish(telemetry.to_json)
    puts " [MUTATION] Window hierarchy layout changed! Pushed spatial update."
  end
rescue ex : Exception
  puts "  [Publisher Error] Failed to stream context payload: #{ex.message}"
end
