require "base64"
require "compress/deflate"
require "json"
require "random/secure"

require "../../src/xephyr_context"

class LatestStateFixture
  getter context : XephyrContext

  @connection : AMQP::Client::Connection
  @publisher_channel : AMQP::Client::Channel
  @canvas_queue_name : String
  @spatial_queue_name : String
  @received_states : Channel(XephyrContext::State)

  def initialize
    socket_path = ENV["LAVINMQ_AMQP_UNIXSOCKET"]? ||
                  raise "LAVINMQ_AMQP_UNIXSOCKET must point to a running LavinMQ UNIX socket"

    @connection = AMQP::Client.new(host: socket_path).connect
    context_channel = @connection.channel
    @publisher_channel = @connection.channel

    display_number = "spec-#{Process.pid}-#{Random::Secure.hex(8)}"
    @canvas_queue_name = "xephyr.#{display_number}.canvas.stream"
    @spatial_queue_name = "xephyr.#{display_number}.telemetry.spatial"

    @context = XephyrContext.new(display_number, context_channel)
    @received_states = Channel(XephyrContext::State).new(2)
  end

  def subscribe : Nil
    @context.each_mutation do |state|
      @received_states.send(state)
    end
  end

  def publish_frame(timestamp : Int64, pixels : Bytes) : Nil
    compressed = IO::Memory.new
    Compress::Deflate::Writer.open(compressed) do |writer|
      writer.write(pixels)
    end

    payload = JSON.build do |json|
      json.object do
        json.field "timestamp", timestamp
        json.field "data", Base64.strict_encode(compressed.to_slice)
        json.field "width", 2
        json.field "height", 1
      end
    end

    @publisher_channel.basic_publish(payload, "", @canvas_queue_name)
    nil
  end

  def receive_state : XephyrContext::State
    select
    when state = @received_states.receive
      state
    when timeout(5.seconds)
      raise "Timed out waiting for a canvas state from LavinMQ"
    end
  end

  def close : Nil
    begin
      @context.stop
    ensure
      begin
        @publisher_channel.queue_delete(@canvas_queue_name)
      ensure
        begin
          @publisher_channel.queue_delete(@spatial_queue_name)
        ensure
          @connection.close
        end
      end
    end
  end
end
