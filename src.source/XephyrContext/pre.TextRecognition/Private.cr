private def wait_for_first_result(timeout : Time::Span) : Result
  started_at = Time.instant

  loop do
    if result = @latest_result
      return result if same_region?(result.region, @full_screen)
    end

    remaining = timeout - (Time.instant - started_at)
    raise "Timed out waiting for the first OCR result" if remaining <= 0.seconds

    result = select
    when item = @results.receive
      item
    when timeout(remaining)
      raise "Timed out waiting for the first OCR result"
    end

    return result if same_region?(result.region, @full_screen)
  end
end

private def enqueue(state : State) : Nil
  return if @closed

  region = @active_region
  if previous = @last_enqueued_task
    return if state.timestamp < previous.state.timestamp
    return if state.timestamp == previous.state.timestamp && same_region?(region, previous.region)
  end

  task = Task.new(state, region)
  @last_enqueued_task = task
  replace_pending(task)
end

private def replace_pending(task : Task?) : Nil
  select
  when @pending_states.send(task)
    nil
  else
    select
    when @pending_states.receive
      nil
    else
      nil
    end

    select
    when @pending_states.send(task)
      nil
    else
      nil
    end
  end
end

private def process_pending_states : Nil
  begin
    loop do
      task = @pending_states.receive
      break unless task

      process(task)
    end
  ensure
    begin
      @recognizer.close
    ensure
      @worker_done.send(nil)
    end
  end
end

private def process(task : Task) : Nil
  started_at = Time.instant
  result = begin
    text = @recognizer.recognize(task.state, task.region)
    Result.new(task.state, text, task.region, Time.instant - started_at)
  rescue ex : Exception
    Result.new(
      task.state,
      "",
      task.region,
      Time.instant - started_at,
      "#{ex.class}: #{ex.message}"
    )
  end

  @latest_result = result
  publish_result(result)

  Log.trace do
    "[TextRecognition] processed frame=#{result.timestamp} region=#{result.region.inspect} " +
      "duration_ms=#{result.duration.total_milliseconds.round(1)} success=#{result.success?}"
  end
end

private def publish_result(result : Result) : Nil
  select
  when @results.send(result)
    nil
  else
    select
    when @results.receive
      nil
    else
      nil
    end

    select
    when @results.send(result)
      nil
    else
      nil
    end
  end
end

private def receive_result(
  expected : String,
  timeout : Time::Span?,
  started_at : Time::Instant
) : Result
  return @results.receive unless timeout

  remaining = timeout - (Time.instant - started_at)
  raise "Timed out waiting for #{expected.inspect}" if remaining <= 0.seconds

  select
  when result = @results.receive
    result
  when timeout(remaining)
    raise "Timed out waiting for #{expected.inspect}"
  end
end

private def same_region?(first : ScreenRegion, second : ScreenRegion) : Bool
  first.x == second.x &&
    first.y == second.y &&
    first.width == second.width &&
    first.height == second.height
end
