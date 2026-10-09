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
  previous_received_at : Time::Instant? = nil
  @channel.basic_consume(@name, tag: consumer_tag || "", no_ack: false, args: args) do |msg|
    if @stopped
      begin
        @channel.basic_ack(msg.delivery_tag)
      rescue ex : Exception
        STDERR.puts " [Stream] ACK after stop failed: #{ex.class}: #{ex.message}"
      end
      next
    end

    received_at = Time.instant
    receive_interval_ms = previous_received_at.try { |previous| (received_at - previous).total_milliseconds.round(1) }
    previous_received_at = received_at
    parse_started_at = Time.instant

    begin
      payload = JSON.parse(msg.body_io)
      parsed_at = Time.instant
      payload_timestamp = payload["timestamp"]?.try(&.as_i64)
      now_ms = Time.utc.to_unix_ms
      producer_lag_ms = payload_timestamp.try { |timestamp| now_ms - timestamp if timestamp > now_ms - 86_400_000 && timestamp < now_ms + 60_000 }

      callback_started_at = Time.instant
      block.call payload
      callback_duration_ms = (Time.instant - callback_started_at).total_milliseconds.round(1)
      parse_duration_ms = (parsed_at - parse_started_at).total_milliseconds.round(1)
      puts " [Stream timing] name=#{@name.inspect} frame=#{payload_timestamp || "unknown"} producer_lag_ms=#{producer_lag_ms || "unknown"} receive_interval_ms=#{receive_interval_ms || "first"} parse_ms=#{parse_duration_ms} callback_ms=#{callback_duration_ms}"
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
