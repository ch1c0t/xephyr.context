# Returns the cached result only when it belongs to the current framebuffer
# and was recognized using the normal full-screen region.
def latest_for_current_state : Result?
  return if @closed

  state = @context.latest_state || return
  result = @latest_result || return
  return unless result.timestamp == state.timestamp
  return unless same_region?(result.region, @full_screen)

  result
end

# Waits until the current framebuffer (or a newer one) has a full-screen OCR
# result. Once cached, subsequent calls return that same result immediately.
def wait_for_current_state(timeout : Time::Span = 10.seconds) : Result
  raise "Text recognition is closed" if @closed

  if state = @context.latest_state
    wait_for(state.timestamp, timeout, @full_screen)
  else
    wait_for_first_result(timeout)
  end
end

def wait_for(
  timestamp : Int64,
  timeout : Time::Span = 10.seconds,
  region : ScreenRegion? = nil
) : Result
  raise "Text recognition is closed" if @closed

  target_region = region || @full_screen
  if result = @latest_result
    return result if result.timestamp >= timestamp && same_region?(result.region, target_region)
  end

  started_at = Time.instant
  loop do
    remaining = timeout - (Time.instant - started_at)
    raise "Timed out waiting for OCR result for frame #{timestamp}" if remaining <= 0.seconds

    result = select
    when item = @results.receive
      item
    when timeout(remaining)
      raise "Timed out waiting for OCR result for frame #{timestamp}"
    end

    return result if result.timestamp >= timestamp && same_region?(result.region, target_region)

    if latest = @latest_result
      return latest if latest.timestamp >= timestamp && same_region?(latest.region, target_region)
    end
  end
end

# Uses the same background recognizer as wait_for_current_state. A region
# override is applied to subsequent frames for the duration of this wait.
def wait_until(
  expected : String,
  timeout : Time::Span? = nil,
  region : ScreenRegion = ScreenRegion.full_screen
) : State
  wait_until(expected, timeout, region) {}
end

def wait_until(
  expected : String,
  timeout : Time::Span? = nil,
  region : ScreenRegion = ScreenRegion.full_screen,
  &trigger
) : State
  raise "Text recognition is closed" if @closed

  baseline_timestamp = @context.latest_state.try(&.timestamp) || -1_i64
  @active_region = region
  Log.debug { "[TextRecognition] waiting for #{expected.inspect} in region=#{region.inspect}" }
  yield

  started_at = Time.instant
  expected_text = expected.downcase

  loop do
    result = receive_result(expected, timeout, started_at)
    next unless result.timestamp > baseline_timestamp
    next unless same_region?(result.region, region)

    baseline_timestamp = result.timestamp
    if error = result.error
      raise "OCR failed for frame #{result.timestamp}: #{error}"
    end

    Log.trace do
      " [TextRecognition] frame=#{result.timestamp} region=#{region.inspect} " +
        "OCR_ms=#{result.duration.total_milliseconds.round(1)} text=#{result.text.inspect}"
    end

    if result.text.downcase.includes?(expected_text)
      Log.debug { "[TextRecognition] matched #{expected.inspect} at frame=#{result.timestamp}" }
      return result.state
    end
  end
ensure
  unless @closed
    @active_region = @full_screen
    if state = @context.latest_state
    enqueue(state)
  end
  end
end

def close : Nil
  return if @closed

  @closed = true
  @context.remove_mutation_callback(@mutation_callback)
  replace_pending(nil)
  @worker_done.receive
end
