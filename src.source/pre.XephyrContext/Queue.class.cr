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
