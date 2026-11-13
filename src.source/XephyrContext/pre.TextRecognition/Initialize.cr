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
    if state = @context.latest_state
    enqueue(state)
  end
  rescue ex : Exception
    close
    raise ex
  end
end
