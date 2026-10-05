getter name : String

def initialize(@name : String, @channel : ::AMQP::Client::Channel)
  queue_args = ::AMQP::Client::Arguments.new({"x-max-age" => "2D"})
  @channel.queue_declare(name: @name, args: queue_args, durable: true)
end

def consume(&block : JSON::Any ->) : Nil
  puts " [Queue] consume name=#{@name.inspect}"

  @channel.basic_consume(@name, no_ack: true) do |msg|
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
