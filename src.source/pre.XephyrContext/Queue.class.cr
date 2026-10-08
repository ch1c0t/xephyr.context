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
