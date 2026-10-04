require "json"
require "./x11"

class Daemon
  def initialize(@display_target : String = Global.display)
  end
  
  def run
    display = X11::Display.new(@display_target)
  
    begin
      absorber = Absorber.new(display)
      absorber.summarize
  
      publisher = Publisher.new
  
      each Global.interval do
        context = absorber.absorb
        canvas = context.canvas
  
        if canvas.changed?
          puts "[MUTATION] Pixels changed inside the sandbox!"
          publisher.call context
        else
          puts "No mutations"
        end
  
        canvas.destroy
      end
    ensure
      display.close
    end
  end

  class Absorber
    module Absorb
      # 💡 THINK: Captures everything on the display right now
      def absorb(width : Int32? = nil, height : Int32? = nil) : X11::Context
        root = @display.root_window
      
        if width.nil? || height.nil?
          res = @display.resolution
          width ||= res[:width]
          height ||= res[:height]
        end
      
        # Step 2: Build the structural data mapping array
        windows = fetch_window_list(root)
      
        # Step 3: Capture the physical frame snapshot map
        canvas = X11::Image.new(@display, root, width, height)
      
        # Return the clean, unified payload package
        X11::Context.new(windows, canvas)
      end
    end
  
    module FetchWindowList
      # 💡 THINK: Hidden pointer gymnastics cleanly boxed away
      private def fetch_window_list(root : LibX11::Window) : Array(X11::Window)
        root_ret = uninitialized LibX11::Window
        parent_ret = uninitialized LibX11::Window
        nchildren = uninitialized LibC::UInt
        children_ptr = uninitialized LibX11::Window*
      
        status = LibX11.XQueryTree(@display.handle, root, pointerof(root_ret), pointerof(parent_ret), pointerof(children_ptr), pointerof(nchildren))
      
        list = [] of X11::Window
      
        if status != 0 && !children_ptr.null?
          Slice.new(children_ptr, nchildren.to_i32).each do |id|
            list << X11::Window.new(id, @display)
          end
          LibX11.XFree(children_ptr.as(Void*)) # Burn C memory allocations immediately
        end
      
        list
      end
    end
  
    module Summarize
      def summarize : Nil
        context = absorb
        begin
          context.summarize
        ensure
          # Guaranteed execution block to ensure zero memory leaks
          context.canvas.try(&.destroy)
        end
      end
    end
  
    def initialize(@display : X11::Display)
    end
    
    include Absorb
    include Summarize
    include FetchWindowList
  end

  class Publisher
    module Call
      def call(context : X11::Context) : Nil
        # 1. Visual data pipeline execution pass
        canvas_json = serialize_canvas(context.canvas)
        @canvas_queue.publish(canvas_json)
      
        # 2. Dynamic telemetry initialization pass
        telemetry = Telemetry.new(context.windows, @spatial_queue.name)
      
        # 💡 PURE ENCAPSULATION: The queue manages its own socket delivery payload!
        if telemetry.changed?
          @spatial_queue.publish(telemetry.to_json)
          puts " [MUTATION] Window hierarchy layout changed! Pushed spatial update."
        end
      rescue ex : Exception
        puts "  [Publisher Error] Failed to stream context payload: #{ex.message}"
      end
    end
  
    class Queue
      getter name : String
      
      def initialize(@name : String)
        # Pull the non-nillable global channel context directly on allocation
        @channel = Global.amqp_channel
      
        # Declare synchronously instantly to assert queue presence on LavinMQ
        queue_args = ::AMQP::Client::Arguments.new({"x-max-age" => "2D"})
        @channel.queue_declare(name: @name, args: queue_args, durable: true)
      end
      
      def publish(message : String) : Nil
        @channel.basic_publish(message, exchange: "", routing_key: @name)
      end
    end
  
    module SerializeCanvas
      private def serialize_canvas(canvas : X11::Image) : String
        compressed_bytes = canvas.to_deflate
        {
          "routing_key" => @canvas_queue.name,
          "timestamp"   => Time.local.to_unix,
          "bytes_size"  => compressed_bytes.size,
          "width"       => canvas.width,
          "height"      => canvas.height,
          "data"        => Base64.strict_encode(compressed_bytes)
        }.to_json
      end
    end
  
    class Telemetry
      getter current_hash : UInt64
      @data : NamedTuple(routing_key: String, timestamp: Int64, windows: Array(JSON::Any))
      
      # =========================================================================
      # CLASS VARIABLE: Persists across the entire application lifetime process
      # =========================================================================
      @@last_hash : UInt64 = 0_u64
      
      def initialize(windows : Array(X11::Window), routing_key : String)
        raw_windows = windows.map do |win|
          geom = win.geometry
          {
            "id"      => win.id.to_u64,
            "title"   => win.title,
            "spatial" => {
              "x" => geom[:x], "y" => geom[:y], "width" => geom[:width], "height" => geom[:height], "visible" => geom[:visible]
            }
          }
        end
      
        parsed_windows = JSON.parse(raw_windows.to_json).as_a
        @current_hash = parsed_windows.hash
      
        @data = {
          routing_key: routing_key,
          timestamp:   Time.local.to_unix,
          windows:     parsed_windows
        }
      end
      
      # 💡 NO ARGUMENTS NEEDED: Evaluates and updates history tracking state internally
      def changed? : Bool
        if @current_hash != @@last_hash
          @@last_hash = @current_hash
          true
        else
          false
        end
      end
      
      def to_json : String
        @data.to_json
      end
    end
  
    getter canvas_queue : Queue
    getter spatial_queue : Queue
    
    def initialize
      num = Global.display_number
      @canvas_queue  = Queue.new("xephyr.#{num}.canvas.delta")
      @spatial_queue = Queue.new("xephyr.#{num}.telemetry.spatial")
    end
    
    include Call
    include SerializeCanvas
  end
end