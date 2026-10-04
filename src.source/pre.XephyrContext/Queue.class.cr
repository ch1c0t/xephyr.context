getter name : String
getter stream : Bool

def initialize(@name : String, @channel : ::AMQP::Client::Channel, @stream : Bool = false)
  queue_args = queue_arguments
  @channel.queue_declare(name: @name, args: queue_args, durable: true)

  @channel.prefetch(100) if @stream
end

def consume(offset : String? = nil, &block : JSON::Any ->) : Nil
  args = consumer_arguments(offset)

  @channel.basic_consume(@name, no_ack: !@stream, args: args) do |msg|
    begin
      payload = JSON.parse(msg.body_io)
      block.call payload
      @channel.basic_ack(msg.delivery_tag) if @stream
    rescue ex : Exception
      puts " [XephyrContext Queue Error] Failed to parse stream payload: #{ex.message}"
      @channel.basic_ack(msg.delivery_tag) if @stream
    end
  end
end

private def queue_arguments
  args = {"x-max-age" => "2D"}
  args["x-queue-type"] = "stream" if @stream
  ::AMQP::Client::Arguments.new(args)
end

private def consumer_arguments(offset : String?) : ::AMQP::Client::Arguments
  args = {} of String => String
  args["x-stream-offset"] = offset if @stream && offset
  ::AMQP::Client::Arguments.new(args)
end
