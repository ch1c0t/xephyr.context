require "amqp-client"
require "compress/deflate"
require "base64"
require "json"

class XephyrContext
  module EachMutation
    def each_mutation(&block : State ->)
      # Stream 1: Update the live layout metadata cache asynchronously
      @spatial_queue.consume do |payload|
        @current_spatial_data = parse_spatial_windows(payload)
      end
    
      # Stream 2: Assemble and deliver a mixed world state snapshot asynchronously
      @canvas_queue.consume do |payload|
        block.call(build_state_snapshot(payload))
      rescue ex : Exception
        puts " [XephyrContext Client Error] Failed parsing canvas mutation: #{ex.message}"
      end
    end
  end

  module Private
    private def build_state_snapshot(payload : JSON::Any) : State
      timestamp = payload["timestamp"].as_i64
      raw_pixels = inflate_canvas_bytes(payload["data"].as_s)
    
      State.new(
        windows:    @current_spatial_data, # Blends from the active spatial background cache
        raw_pixels: raw_pixels,
        timestamp:  timestamp
      )
    end
    
    private def parse_spatial_windows(payload : JSON::Any) : Array(JSON::Any)
      payload["windows"]?.try(&.as_a) || [] of JSON::Any
    rescue Exception
      [] of JSON::Any
    end
    
    private def inflate_canvas_bytes(base64_string : String) : Slice(UInt8)
      compressed_bytes = Base64.decode(base64_string)
      decompressed_io = IO::Memory.new
      IO.copy(Compress::Deflate::Reader.new(IO::Memory.new(compressed_bytes)), decompressed_io)
      decompressed_io.to_slice
    end
  end

  class Queue
    getter name : String
    
    def initialize(@name : String, @channel : ::AMQP::Client::Channel)
    end
    
    # Subscribes to the queue and yields a fully parsed JSON::Any object to the block
    def consume(&block : JSON::Any ->) : Nil
      @channel.basic_consume(@name, no_ack: true) do |msg|
        begin
          payload = JSON.parse(msg.body_io)
          block.call payload
        rescue ex : Exception
          puts " [XephyrContext Queue Error] Failed to parse stream payload: #{ex.message}"
        end
      end
    end
  end

  class State
    getter windows : Array(JSON::Any)
    getter raw_pixels : Slice(UInt8)
    getter timestamp : Int64
    
    def initialize(@windows, @raw_pixels, @timestamp)
    end
  end

  @display_number : String
  @current_spatial_data = [] of JSON::Any
  
  def initialize(display_target : String, channel : ::AMQP::Client::Channel)
    @display_number = display_target.delete(':')
    @canvas_queue  = Queue.new "xephyr.#{@display_number}.canvas.delta", channel
    @spatial_queue = Queue.new "xephyr.#{@display_number}.telemetry.spatial", channel
  end
  
  include Private
  include EachMutation
end