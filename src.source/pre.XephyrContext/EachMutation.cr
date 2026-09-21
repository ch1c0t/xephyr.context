def each_mutation(&block : State ->)
  # Stream 1: Update the live layout metadata cache asynchronously
  @spatial_queue.consume do |payload|
    @current_spatial_data = parse_spatial_windows(payload)
  end

  # Stream 2: Assemble and deliver a mixed world state snapshot asynchronously
  @canvas_queue.consume do |payload|
    block.call(build_state_snapshot(payload))
  rescue ex : Exception
    puts " [XephyrContext Client Error] Failed parsing canvas mutation: #{ex.message}"
  end
end
