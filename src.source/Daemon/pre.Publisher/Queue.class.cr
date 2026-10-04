getter name : String
getter stream : Bool

def initialize(@name : String, @stream : Bool = false)
  @channel = Global.amqp_channel

  queue_args = queue_arguments
  @channel.queue_declare(name: @name, args: queue_args, durable: true)

  @channel.prefetch(100) if @stream
end

def publish(message : String) : Nil
  @channel.basic_publish(message, exchange: "", routing_key: @name)
end

private def queue_arguments
  args = {"x-max-age" => "2D"}
  args["x-queue-type"] = "stream" if @stream
  ::AMQP::Client::Arguments.new(args)
end
