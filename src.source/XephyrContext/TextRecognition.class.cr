  class Result
    getter state : State
    getter text : String
    getter region : ScreenRegion
    getter duration : Time::Span
    getter error : String?

    def initialize(
      @state : State,
      @text : String,
      @region : ScreenRegion,
      @duration : Time::Span,
      @error : String? = nil
    )
    end

    def timestamp : Int64
      @state.timestamp
    end

    def success? : Bool
      @error.nil?
    end
  end

  private struct Task
    getter state : State
    getter region : ScreenRegion

    def initialize(@state : State, @region : ScreenRegion)
    end
  end

  @recognizer : TextRecognizer
  @pending_states : Channel(Task?)
  @results : Channel(Result)
  @worker_done : Channel(Nil)
  @mutation_callback : Proc(State, Nil)
  @full_screen : ScreenRegion
  @active_region : ScreenRegion
  @last_enqueued_task : Task? = nil
  @latest_result : Result? = nil
  @closed = false

  def initialize(@context : XephyrContext, language : String = "eng")
    @full_screen = ScreenRegion.full_screen
    @active_region = @full_screen
    @recognizer = TextRecognizer.new(language)
    @pending_states = Channel(Task?).new(1)
    @results = Channel(Result).new(64)
    @worker_done = Channel(Nil).new(1)
    @mutation_callback = Proc(State, Nil).new { |state| enqueue(state) }

    spawn { process_pending_states }

    begin
      @context.each_mutation(&@mutation_callback)
      enqueue(state) if state = @context.latest_state
    rescue ex : Exception
      close
      raise ex
    end
  end

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
      enqueue(state) if state = @context.latest_state
    end
  end

  def close : Nil
    return if @closed

    @closed = true
    @context.remove_mutation_callback(@mutation_callback)
    replace_pending(nil)
    @worker_done.receive
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
