def replay_mutations(offset : String = "first", &block : State ->) : Nil
  @canvas_queue.consume(offset) do |payload|
    state = build_state_snapshot(payload)
    block.call(state)
  rescue ex : Exception
    puts " [XephyrContext Replay Error] Failed parsing canvas mutation: #{ex.message}"
  end
end
