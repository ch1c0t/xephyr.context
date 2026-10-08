@display_number : String
@current_spatial_data = [] of JSON::Any

def initialize(display_target : String, channel : ::AMQP::Client::Channel)
  @display_number = display_target.delete(':')
  @consumer_prefix = "xephyr-context-#{object_id}"
  @canvas_queue  = Stream.new "xephyr.#{@display_number}.canvas.stream", channel
  @spatial_queue = Queue.new "xephyr.#{@display_number}.telemetry.spatial", channel
end

include Private
include EachMutation
include WaitUntil
include Replay
