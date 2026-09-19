def summarize : Nil
  context = absorb
  begin
    context.summarize
  ensure
    # Guaranteed execution block to ensure zero memory leaks
    context.canvas.try(&.destroy)
  end
end
