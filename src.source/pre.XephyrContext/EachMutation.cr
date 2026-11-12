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
  begin
    @canvas_queue.stop
  ensure
    @spatial_queue.stop
  end
end

private def start_mutation_consumers : Nil
  return if @mutation_consumers_started || @stopped

  @mutation_consumers_started = true

  @spatial_queue.consume("#{@consumer_prefix}-spatial") do |payload|
    next if @stopped

    windows = parse_spatial_windows(payload)
    next if windows == @current_spatial_data

    @current_spatial_data = windows

    if previous_state = @latest_state
      state = State.new(
        windows:    windows,
        raw_pixels: previous_state.raw_pixels,
        width:      previous_state.width,
        height:     previous_state.height,
        timestamp:  previous_state.timestamp
      )

      @latest_state = state
      @mutation_callbacks.each(&.call(state))
      Log.trace { "[XephyrContext] Spatial metadata changed windows=#{windows.size} frame=#{state.timestamp}" }
    end
  rescue ex : Exception
    Log.error(exception: ex) { "[XephyrContext Client Error] Failed applying spatial mutation: #{ex.message}" }
  end

  @canvas_queue.consume("next", "#{@consumer_prefix}-canvas") do |payload|
    next if @stopped

    state = build_state_snapshot(payload)
    @latest_state = state
    @mutation_callbacks.each(&.call(state))
  rescue ex : Exception
    Log.error(exception: ex) { "[XephyrContext Client Error] Failed parsing canvas mutation: #{ex.message}" }
  end
end
