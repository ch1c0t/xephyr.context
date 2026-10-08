@mutation_callbacks = [] of Proc(State, Nil)
@mutation_consumers_started = false
@stopped = false

def each_mutation(&block : State ->)
  raise "XephyrContext is stopped" if @stopped

  @mutation_callbacks << block
  start_mutation_consumers
end

def stop : Nil
  return if @stopped

  @stopped = true
  @mutation_callbacks.clear
  @canvas_queue.stop
  @spatial_queue.stop
end

private def start_mutation_consumers : Nil
  return if @mutation_consumers_started || @stopped

  @mutation_consumers_started = true

  @spatial_queue.consume("#{@consumer_prefix}-spatial") do |payload|
    next if @stopped
    @current_spatial_data = parse_spatial_windows(payload)
  end

  @canvas_queue.consume("next", "#{@consumer_prefix}-canvas") do |payload|
    next if @stopped

    state = build_state_snapshot(payload)
    @mutation_callbacks.each(&.call(state))
  rescue ex : Exception
    puts " [XephyrContext Client Error] Failed parsing canvas mutation: #{ex.message}"
  end
end
