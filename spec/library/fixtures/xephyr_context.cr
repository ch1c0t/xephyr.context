require "base64"
require "compress/deflate"
require "json"
require "random/secure"

require "../../../src/xephyr_context"

class XephyrContextFixture
  getter context : XephyrContext
  getter display_target : String

  @connection : AMQP::Client::Connection
  @publisher_channel : AMQP::Client::Channel
  @canvas_queue_name : String
  @spatial_queue_name : String
  @received_states : Channel(XephyrContext::State)

  def initialize(display_target : String? = nil)
    socket_path = ENV["LAVINMQ_AMQP_UNIXSOCKET"]? ||
                  raise "LAVINMQ_AMQP_UNIXSOCKET must point to a running LavinMQ UNIX socket"

    @connection = AMQP::Client.new(host: socket_path).connect
    context_channel = @connection.channel
    @publisher_channel = @connection.channel

    @display_target = display_target || "spec-#{Process.pid}-#{Random::Secure.hex(8)}"
    display_number = @display_target.delete(':')
    @canvas_queue_name = "xephyr.#{display_number}.canvas.stream"
    @spatial_queue_name = "xephyr.#{display_number}.telemetry.spatial"

    @context = XephyrContext.new(@display_target, context_channel)
    @received_states = Channel(XephyrContext::State).new(2)
  end

  def subscribe : Nil
    subscribe do |state|
      @received_states.send(state)
    end
  end

  def subscribe(&block : XephyrContext::State ->) : Nil
    @context.each_mutation(&block)
  end

  def publish_frame(
    timestamp : Int64,
    pixels : Bytes,
    width : Int32 = 2,
    height : Int32 = 1
  ) : Nil
    compressed = IO::Memory.new
    Compress::Deflate::Writer.open(compressed) do |writer|
      writer.write(pixels)
    end

    payload = JSON.build do |json|
      json.object do
        json.field "timestamp", timestamp
        json.field "data", Base64.strict_encode(compressed.to_slice)
        json.field "width", width
        json.field "height", height
      end
    end

    @publisher_channel.basic_publish(payload, "", @canvas_queue_name)
    nil
  end

  def publish_spatial(
    windows : Array(JSON::Any),
    timestamp : Int64 = Time.utc.to_unix
  ) : Nil
    payload = JSON.build do |json|
      json.object do
        json.field "routing_key", @spatial_queue_name
        json.field "timestamp", timestamp
        json.field "windows", windows
      end
    end

    @publisher_channel.basic_publish(payload, "", @spatial_queue_name)
    nil
  end

  def receive_state : XephyrContext::State
    receive_state_from(@received_states)
  end

  def receive_state_from(
    channel : Channel(XephyrContext::State),
    within : Time::Span = 5.seconds
  ) : XephyrContext::State
    select
    when state = channel.receive
      state
    when timeout(within)
      raise "Timed out waiting for a canvas state from LavinMQ"
    end
  end

  def receive_state_from_or_nil(
    channel : Channel(XephyrContext::State),
    within : Time::Span
  ) : XephyrContext::State?
    select
    when state = channel.receive
      state
    when timeout(within)
      nil
    end
  end

  def receive_state_or_nil(within : Time::Span) : XephyrContext::State?
    receive_state_from_or_nil(@received_states, within)
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
