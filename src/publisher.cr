require "json"

class Publisher
  module BroadcastCompressedCanvas
    # 💡 THINK: Just builds the delivery envelope and writes it out to the line
    private def broadcast_compressed_canvas(canvas : X11::Image)
      # 1. Ask the canvas to pack and compress itself natively
      compressed_bytes = canvas.to_deflate
    
      # 2. Package into a readable JSON container payload block
      payload = {
        "exchange"    => "xephyr.context",
        "routing_key" => "xephyr.canvas.delta",
        "timestamp"   => Time.local.to_unix,
        "bytes_size"  => compressed_bytes.size,
        "data"        => Base64.strict_encode(compressed_bytes)
      }.to_json
    
      # 3. Ship it over the local Unix Domain Socket boundary
      write_to_socket(payload)
    end
    
    def write_to_socket(payload)
      json = JSON.parse payload
      p json["bytes_size"]
    end
  end

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
end