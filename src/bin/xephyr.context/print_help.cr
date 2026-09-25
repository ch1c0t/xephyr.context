HELP_MESSAGE = <<-S
xephyr.context is to stream context of a Xephyr instance to LavinMQ.

It needs the values of two environment variables to work:
  DISPLAY_TARGET=":10"
  LAVINMQ_AMQP_UNIXSOCKET="$HOME/.local/share/lavinmq/amqp.sock"

DISPLAY_TARGET is different for each Xephyr instance(in a user session) and
can be passed as follows:

    DISPLAY_TARGET=":10" xephyr.context

Whenever the state of pixels(inside of a Xephyr instance) changes, a new state
snapshot gets published to the following queues:
  "xephyr.\#{DISPLAY_TARGET}.canvas.delta"
  "xephyr.\#{DISPLAY_TARGET}.telemetry.spatial"

`XephyrContext` is a Crystal class which provides a way to consume the data from
these queues:

    context = XephyrContext.new(Global.display, Global.amqp_channel)

    context.each_mutation do |state|
      puts "\\n--- [Agent Sensed Workspace Mutation] ---"
      puts "Timestamp Reference : \#{state.timestamp}"
      puts "Active App Containers: \#{state.windows.size} elements found."
      puts "Decompressed Pixels : \#{state.raw_pixels.size} bytes loaded dynamically in memory."
    end

xephyr.log_changes and xephyr.save_screenshots_to use it.
S

def print_help
  puts HELP_MESSAGE
end
