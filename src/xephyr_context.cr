require "amqp-client"
require "compress/deflate"
require "base64"
require "json"
require "./lib_tesseract"

class XephyrContext
  module EachMutation
    @mutation_callbacks = [] of Proc(State, Nil)
    @mutation_consumers_started = false
    @stopped = false
    
    def each_mutation(&block : State ->)
      raise "XephyrContext is stopped" if @stopped
    
      @mutation_callbacks << block
      start_mutation_consumers
    end
    
    def stop : Nil
      return if @stopped
    
      @stopped = true
      begin
        @canvas_queue.stop
      ensure
        @spatial_queue.stop
      end
    end
    
    private def start_mutation_consumers : Nil
      return if @mutation_consumers_started || @stopped
    
      @mutation_consumers_started = true
    
      @spatial_queue.consume("#{@consumer_prefix}-spatial") do |payload|
        next if @stopped
        @current_spatial_data = parse_spatial_windows(payload)
      end
    
      @canvas_queue.consume("next", "#{@consumer_prefix}-canvas") do |payload|
        next if @stopped
    
        state = build_state_snapshot(payload)
        @mutation_callbacks.each(&.call(state))
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
        width:      payload["width"].as_i,
        height:     payload["height"].as_i,
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
      decompressed_io.to_slice.dup
    end
  end

  class Queue
    getter name : String
    @consumer_tag : String? = nil
    @stopped = false
    
    def initialize(@name : String, @channel : ::AMQP::Client::Channel)
      queue_args = ::AMQP::Client::Arguments.new({"x-max-age" => "2D"})
      @channel.queue_declare(name: @name, args: queue_args, durable: true)
    end
    
    def consume(consumer_tag : String? = nil, &block : JSON::Any ->) : Nil
      puts " [Queue] consume name=#{@name.inspect}"
    
      @consumer_tag = consumer_tag
      @stopped = false
      @channel.basic_consume(@name, tag: consumer_tag || "", no_ack: true) do |msg|
        next if @stopped
    
        puts " [Queue] message received name=#{@name.inspect}"
    
        begin
          payload = JSON.parse(msg.body_io)
          puts " [Queue] payload parsed name=#{@name.inspect}"
    
          block.call payload
          puts " [Queue] callback completed name=#{@name.inspect}"
        rescue ex : Exception
          puts " [Queue] ERROR name=#{@name.inspect}: #{ex.class}: #{ex.message}"
        end
      end
    
      puts " [Queue] basic_consume registered name=#{@name.inspect}"
    end
    
    def stop : Nil
      @stopped = true
      consumer_tag = @consumer_tag
      return unless consumer_tag
    
      @consumer_tag = nil
      @channel.basic_cancel(consumer_tag)
    end
  end

  module Replay
    def replay_mutations(offset : String = "first", &block : State ->) : Nil
      @canvas_queue.consume(offset) do |payload|
        state = build_state_snapshot(payload)
        block.call(state)
      rescue ex : Exception
        puts " [XephyrContext Replay Error] Failed parsing canvas mutation: #{ex.message}"
      end
    end
  end

  class State
    getter windows : Array(JSON::Any)
    getter raw_pixels : Slice(UInt8)
    getter timestamp : Int64
    
    getter width : Int32
    getter height : Int32
    
    def initialize(@windows, @raw_pixels, @timestamp, @width, @height)
    end
  end

  class Stream
    getter name : String
    @consumer_tag : String? = nil
    @stopped = false
    
    def initialize(@name : String, @channel : ::AMQP::Client::Channel)
      queue_args = ::AMQP::Client::Arguments.new({
        "x-max-age" => "2D",
        "x-queue-type" => "stream",
      })
    
      puts " [Stream] declare name=#{@name.inspect}"
      @channel.queue_declare(name: @name, args: queue_args, durable: true)
      @channel.prefetch(100)
    end
    
    def consume(offset : String? = nil, consumer_tag : String? = nil, &block : JSON::Any ->) : Nil
      puts " [Stream] consume name=#{@name.inspect} offset=#{offset.inspect}"
    
      args = consumer_arguments(offset)
      puts " [Stream] basic_consume name=#{@name.inspect}"
    
      @consumer_tag = consumer_tag
      @stopped = false
      @channel.basic_consume(@name, tag: consumer_tag || "", no_ack: false, args: args) do |msg|
        if @stopped
          begin
            @channel.basic_ack(msg.delivery_tag)
          rescue ex : Exception
            STDERR.puts " [Stream] ACK after stop failed: #{ex.class}: #{ex.message}"
          end
          next
        end
    
        begin
          payload = JSON.parse(msg.body_io)
    
          block.call payload
        rescue ex : Exception
          puts " [Stream] ERROR name=#{@name.inspect}: #{ex.class}: #{ex.message}"
        ensure
          begin
            @channel.basic_ack(msg.delivery_tag)
          rescue ack_error : Exception
            STDERR.puts " [Stream] ACK failed: #{ack_error.class}: #{ack_error.message}"
          end
        end
      end
    
      puts " [Stream] basic_consume registered name=#{@name.inspect}"
    end
    
    def stop : Nil
      @stopped = true
      consumer_tag = @consumer_tag
      return unless consumer_tag
    
      @consumer_tag = nil
      @channel.basic_cancel(consumer_tag)
    end
    
    private def consumer_arguments(offset : String?) : ::AMQP::Client::Arguments
      args = {} of String => String
      args["x-stream-offset"] = offset if offset
      ::AMQP::Client::Arguments.new(args)
    end
  end

  module WaitUntil
    def wait_until(expected : String, timeout : Time::Span? = nil) : State
      wait_until(expected, timeout) {}
    end
    
    def wait_until(expected : String, timeout : Time::Span? = nil, &trigger) : State
      waiter = Channel(State).new(1)
      # Never block the AMQP consumer while OCR is processing a frame.
      # Keep only the newest state waiting for the recognizer.
      callback = Proc(State, Nil).new do |state|
        select
        when waiter.send(state)
        else
          select
          when waiter.receive
            nil
          else
            nil
          end

          select
          when waiter.send(state)
            nil
          else
            nil
          end
        end
        nil
      end
    
      @mutation_callbacks << callback
      start_mutation_consumers
      puts " [wait_until] waiting for #{expected.inspect}"
      yield
    
      recognizer = TextRecognizer.new
      started_at = Time.instant
      expected_text = expected.downcase
    
      begin
        loop do
          state = receive_waiting_state(waiter, expected, timeout, started_at)
          text = recognizer.recognize(state)
          puts " [wait_until] OCR: #{text.inspect}"
    
          if text.downcase.includes?(expected_text)
            puts " [wait_until] matched #{expected.inspect}"
            return state
          end
        end
      ensure
        recognizer.finalize
      end
    ensure
      @mutation_callbacks.delete(callback) if callback
    end
    
    private def receive_waiting_state(waiter : Channel(State), expected : String, timeout : Time::Span?, started_at : Time::Instant) : State
      return waiter.receive unless timeout
    
      remaining = timeout - (Time.instant - started_at)
      raise "Timed out waiting for #{expected.inspect}" if remaining <= 0.seconds
    
      select
      when state = waiter.receive
        state
      when timeout(remaining)
        raise "Timed out waiting for #{expected.inspect}"
      end
    end
  end

  @display_number : String
  @consumer_prefix : String
  @current_spatial_data = [] of JSON::Any
  
  def initialize(display_target : String, channel : ::AMQP::Client::Channel)
    @display_number = display_target.delete(':')
    @consumer_prefix = "xephyr-context-#{object_id}"
    @canvas_queue  = Stream.new "xephyr.#{@display_number}.canvas.stream", channel
    @spatial_queue = Queue.new "xephyr.#{@display_number}.telemetry.spatial", channel
  end
  
  include Private
  include EachMutation
  include WaitUntil
  include Replay

  class Inspector
    getter display : String
    getter context : XephyrContext
    
    def initialize(@display : String, channel : ::AMQP::Client::Channel)
      @context = XephyrContext.new(display, channel)
    end
    
    def watch(ocr : Bool = false, save_dir : String? = nil, count : Int32? = nil) : Nil
      inspect_stream(ocr, save_dir, count) do |block|
        @context.each_mutation(&block)
      end
    end
    
    def replay(offset : String, ocr : Bool = false, save_dir : String? = nil, count : Int32? = nil) : Nil
      inspect_stream(ocr, save_dir, count) do |block|
        @context.replay_mutations(offset, &block)
      end
    end
    
    private def inspect_stream(
      ocr : Bool,
      save_dir : String?,
      count : Int32?,
      &subscribe : Proc(Proc(XephyrContext::State, Nil), Nil)
    ) : Nil
      recognizer = XephyrContext::TextRecognizer.new if ocr
      seen = 0
      done = Channel(Nil).new(1)
    
      begin
        callback = Proc(XephyrContext::State, Nil).new do |state|
          seen += 1
          report(state, recognizer, save_dir)
          done.send(nil) if count && seen >= count
          nil
        end
    
        subscribe.call(callback)
        count ? done.receive : sleep
      ensure
        recognizer.try(&.finalize)
      end
    end
    
    private def report(
      state : XephyrContext::State,
      recognizer : XephyrContext::TextRecognizer?,
      save_dir : String?
    ) : Nil
      puts "[MUTATION] timestamp=#{state.timestamp} size=#{state.width}x#{state.height} " +
           "pixels=#{state.raw_pixels.size} windows=#{state.windows.size}"
    
      screenshot = Screenshot.new(state, recognizer)
      text = recognizer ? screenshot.recognized_text : nil
      puts "  [OCR] #{text.strip.inspect}" if text
    
      if save_dir
        screenshot.save_to(save_dir, save_image: true, save_text: !text.nil?)
        puts "  [SAVED] #{File.join(save_dir, "frame_#{state.timestamp}.png")}"
        puts "  [SAVED] #{File.join(save_dir, "frame_#{state.timestamp}.txt")}" if text
      end
    end
  end

  class TextRecognizer
    def initialize(@language : String = "eng")
      @api = LibTesseract.TessBaseAPICreate
      raise "Tesseract failed to create API" if @api.null?
    
      status = LibTesseract.TessBaseAPIInit3(
        @api,
        Pointer(LibC::Char).null,
        @language.to_unsafe.as(LibC::Char*)
      )
    
      if status != 0
        LibTesseract.TessBaseAPIDelete(@api)
        raise "Tesseract failed to initialize for language #{@language} (exit code #{status})"
      end
    end
    
    def recognize(state : XephyrContext::State) : String
      recognize(grayscale_pixels(state), state.width, state.height)
    end
    
    def recognize(pixels : Slice(UInt8), width : Int32, height : Int32) : String
      LibTesseract.TessBaseAPISetImage(
        @api,
        pixels.to_unsafe,
        width,
        height,
        1,
        width
      )
    
      text = LibTesseract.TessBaseAPIGetUTF8Text(@api)
      raise "Tesseract returned no text" if text.null?
    
      begin
        String.new(text.as(UInt8*))
      ensure
        LibTesseract.TessDeleteText(text)
      end
    end
    
    def finalize
      LibTesseract.TessBaseAPIEnd(@api)
      LibTesseract.TessBaseAPIDelete(@api)
    end
    
    private def grayscale_pixels(state : XephyrContext::State) : Slice(UInt8)
      pixels = Slice(UInt8).new(state.width * state.height)
      offset = 0
    
      state.height.times do |y|
        state.width.times do |x|
          pixel = (y * state.width + x) * 4
          b = state.raw_pixels[pixel]
          g = state.raw_pixels[pixel + 1]
          r = state.raw_pixels[pixel + 2]
          pixels[offset] = ((r.to_i * 299 + g.to_i * 587 + b.to_i * 114) // 1000).to_u8
          offset += 1
        end
      end
    
      pixels
    end
  end
end