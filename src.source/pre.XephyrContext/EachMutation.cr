@mutation_callbacks = [] of Proc(State, Nil)
@mutation_consumers_started = false

def each_mutation(&block : State ->)
  @mutation_callbacks << block
  start_mutation_consumers
end

private def start_mutation_consumers : Nil
  return if @mutation_consumers_started

  @mutation_consumers_started = true

  @spatial_queue.consume do |payload|
    @current_spatial_data = parse_spatial_windows(payload)
  end

  @canvas_queue.consume do |payload|
    state = build_state_snapshot(payload)
    @mutation_callbacks.each(&.call(state))
  rescue ex : Exception
    puts " [XephyrContext Client Error] Failed parsing canvas mutation: #{ex.message}"
  end
end
