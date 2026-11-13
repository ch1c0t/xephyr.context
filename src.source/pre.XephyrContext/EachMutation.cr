@mutation_callbacks = [] of Proc(State, Nil)
@mutation_consumers_started = false
@stopped = false

def each_mutation(&block : State ->)
  raise "XephyrContext is stopped" if @stopped

  @mutation_callbacks << block
  start_mutation_consumers
end

def remove_mutation_callback(callback : Proc(State, Nil)) : Nil
  @mutation_callbacks.delete(callback)
  nil
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

include StartMutationConsumers
