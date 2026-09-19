# Generic global pacing controller
def each(interval : Time::Span, &block)
  loop do
    yield
    sleep interval
  end
end
