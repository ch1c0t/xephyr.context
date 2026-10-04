getter canvas_queue : Queue
getter spatial_queue : Queue

def initialize
  num = Global.display_number
  @canvas_queue  = Queue.new("xephyr.#{num}.canvas.stream", true)
  @spatial_queue = Queue.new("xephyr.#{num}.telemetry.spatial")
end

include Call
include SerializeCanvas
