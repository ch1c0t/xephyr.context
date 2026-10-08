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

    puts " [Stream] message received name=#{@name.inspect} delivery_tag=#{msg.delivery_tag}"

    begin
      payload = JSON.parse(msg.body_io)
      puts " [Stream] payload parsed name=#{@name.inspect}"

      block.call payload
      puts " [Stream] callback completed name=#{@name.inspect}"
    rescue ex : Exception
      puts " [Stream] ERROR name=#{@name.inspect}: #{ex.class}: #{ex.message}"
    ensure
      begin
        @channel.basic_ack(msg.delivery_tag)
        puts " [Stream] message acknowledged name=#{@name.inspect} delivery_tag=#{msg.delivery_tag}"
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
