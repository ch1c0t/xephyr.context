def initialize
  @socket_path = ENV["LAVINMQ_AMQP_UNIXSOCKET"]?
  if @socket_path.nil?
    raise "Missing critical environment configuration variable: LAVINMQ_AMQP_UNIXSOCKET"
  end
end

def call(context : X11::Context) : Nil
  broadcast_compressed_canvas context.canvas
  pp! Global.amqp_channel
end

include BroadcastCompressedCanvas
