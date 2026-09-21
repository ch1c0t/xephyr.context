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
