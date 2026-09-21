require "amqp-client"
require "compress/deflate"
require "base64"
require "json"

class XephyrContext
  class State
    getter windows : Array(JSON::Any)
    getter raw_pixels : Slice(UInt8)
    getter timestamp : Int64
    
    def initialize(@windows, @raw_pixels, @timestamp)
    end
  end

  @display_number : String
  @channel : ::AMQP::Client::Channel
  @current_spatial_data = [] of JSON::Any
  
  def initialize(display_target : String, channel : ::AMQP::Client::Channel)
    @display_number = display_target.delete(':')
    @channel = channel
  end
  
  # Stream processing engine traps message frames asynchronously 
  def each_mutation(&block : State ->)
    canvas_queue  = "xephyr.#{@display_number}.canvas.delta"
    spatial_queue = "xephyr.#{@display_number}.telemetry.spatial"
  
    # 1. Pipeline Stream 1: Continuously catch layout tree changes in background
    @channel.basic_consume(spatial_queue, no_ack: true) do |msg|
      begin
        payload = JSON.parse(msg.body_io)
        if window_array = payload["windows"]?
          @current_spatial_data = window_array.as_a
        end
      rescue ex : Exception
        # Suppress framing anomalies to protect loop stability
      end
    end
  
    # 2. Pipeline Stream 2: Main blocking thread waits for physical pixel changes
    puts " [XephyrContext Client] Listening to display streams for workspace :#{@display_number}..."
    @channel.basic_consume(canvas_queue, no_ack: true) do |msg|
      begin
        payload = JSON.parse(msg.body_io)
        timestamp = payload["timestamp"].as_i64
  
        # Inflate the dense, scrot-optimized Zlib compression buffer on-the-fly
        base64_data = payload["data"].as_s
        compressed_bytes = Base64.decode(base64_data)
  
        decompressed_io = IO::Memory.new
        IO.copy(Compress::Deflate::Reader.new(IO::Memory.new(compressed_bytes)), decompressed_io)
        raw_pixel_bytes = decompressed_io.to_slice
  
        # Instantiate a clean state snapshot model and yield it straight to the Agent block loop
        state_snapshot = State.new(
          windows:    @current_spatial_data,
          raw_pixels: raw_pixel_bytes,
          timestamp:  timestamp
        )
  
        block.call(state_snapshot)
      rescue ex : Exception
        puts " [XephyrContext Client Error] Failed parsing mutation package: #{ex.message}"
      end
    end
  end
end