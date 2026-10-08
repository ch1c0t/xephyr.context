def wait_until(expected : String, timeout : Time::Span? = nil) : State
  wait_until(expected, timeout) {}
end

def wait_until(expected : String, timeout : Time::Span? = nil, &trigger) : State
  waiter = Channel(State).new(1)
  # Never block the AMQP consumer while OCR is processing a frame.
  # Keep only the newest state waiting for the recognizer.
  callback = Proc(State, Nil).new do |state|
    select
    when waiter.send(state)
    else
      select
      when waiter.receive
        nil
      else
        nil
      end

      select
      when waiter.send(state)
        nil
      else
        nil
      end
    end
    nil
  end

  @mutation_callbacks << callback
  start_mutation_consumers
  puts " [wait_until] waiting for #{expected.inspect}"
  yield

  recognizer = TextRecognizer.new
  started_at = Time.instant
  expected_text = expected.downcase

  begin
    loop do
      state = receive_waiting_state(waiter, expected, timeout, started_at)
      text = recognizer.recognize(state)
      puts " [wait_until] OCR: #{text.inspect}"

      if text.downcase.includes?(expected_text)
        puts " [wait_until] matched #{expected.inspect}"
        return state
      end
    end
  ensure
    recognizer.finalize
  end
ensure
  @mutation_callbacks.delete(callback) if callback
end

private def receive_waiting_state(waiter : Channel(State), expected : String, timeout : Time::Span?, started_at : Time::Instant) : State
  return waiter.receive unless timeout

  remaining = timeout - (Time.instant - started_at)
  raise "Timed out waiting for #{expected.inspect}" if remaining <= 0.seconds

  select
  when state = waiter.receive
    state
  when timeout(remaining)
    raise "Timed out waiting for #{expected.inspect}"
  end
end
