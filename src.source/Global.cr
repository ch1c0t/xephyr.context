# 1. Thread-safe cached configuration class variables
@@socket_path : String = begin
  path = ENV["LAVINMQ_AMQP_UNIXSOCKET"]?
  raise "Missing critical environment configuration variable: LAVINMQ_AMQP_UNIXSOCKET" if path.nil?
  path
end

@@display : String = ENV.fetch("DISPLAY_TARGET", ":10")
@@display_number : String = @@display.delete(':')

@@amqp_channel : ::AMQP::Client::Channel? = nil

extend Getters
