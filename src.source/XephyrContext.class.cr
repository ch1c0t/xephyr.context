@display_number : String
@current_spatial_data = [] of JSON::Any

def initialize(display_target : String, channel : ::AMQP::Client::Channel)
  @display_number = display_target.delete(':')
  @canvas_queue  = Queue.new "xephyr.#{@display_number}.canvas.delta", channel
  @spatial_queue = Queue.new "xephyr.#{@display_number}.telemetry.spatial", channel
end

include Private
include EachMutation
