module Global
  module Getters
    def socket_path : String
      @@socket_path
    end
    
    def display : String
      @@display
    end
    
    def display_number : String
      @@display_number
    end
  end

  # 1. Thread-safe cached configuration class variables
  @@socket_path : String = begin
    path = ENV["LAVINMQ_AMQP_UNIXSOCKET"]?
    raise "Missing critical environment configuration variable: LAVINMQ_AMQP_UNIXSOCKET" if path.nil?
    path
  end
  
  @@display : String = ENV.fetch("DISPLAY_TARGET", ":10")
  @@display_number : String = @@display.delete(':')
  
  extend Getters
end