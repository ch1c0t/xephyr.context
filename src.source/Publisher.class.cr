def initialize
  @socket_path = ENV["LAVINMQ_AMQP_UNIXSOCKET"]?
  if @socket_path.nil?
    raise "Missing critical environment configuration variable: LAVINMQ_AMQP_UNIXSOCKET"
  end
end

def call(context : X11::Context) : Nil
  pp! context
end
