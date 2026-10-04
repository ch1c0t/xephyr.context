def wait_until(expected : String, timeout : Time::Span? = nil) : State
  wait_until(expected, timeout) {}
end

def wait_until(expected : String, timeout : Time::Span? = nil, &trigger) : State
  waiter = Channel(State).new(1)
  callback = Proc(State, Nil).new do |state|
    waiter.send(state)
    nil
  end

  @mutation_callbacks << callback
  start_mutation_consumers
  yield

  recognizer = TextRecognizer.new
  started_at = Time.monotonic
  expected_text = expected.downcase

  loop do
    state = receive_waiting_state(waiter, expected, timeout, started_at)
    text = recognizer.recognize(state)

    puts " [wait_until] OCR: #{text.inspect}"
    return state if text.downcase.includes?(expected_text)
  end
ensure
  @mutation_callbacks.try(&.delete(callback)) if callback
end

private def receive_waiting_state(waiter : Channel(State), expected : String, timeout : Time::Span?, started_at : Time::Span) : State
  return waiter.receive unless timeout

  remaining = timeout - (Time.monotonic - started_at)
  raise "Timed out waiting for #{expected.inspect}" if remaining <= 0.seconds

  select
  when state = waiter.receive
    state
  when timeout(remaining)
    raise "Timed out waiting for #{expected.inspect}"
  end
end
