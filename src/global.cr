require "amqp-client"

module Global
  module AMQP
    def self.create_channel(socket_path : String) : ::AMQP::Client::Channel
      client = ::AMQP::Client.new host: socket_path
      conn = client.connect
      ch = conn.channel
    
      at_exit do
        puts "\n [Global Cleanup] Tearing down AMQP connection pipes automatically..."
        ch.close
        conn.close
      end
    
      ch
    end
  end

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
    
    def amqp_channel : ::AMQP::Client::Channel
      @@amqp_channel ||= Global::AMQP.create_channel(Global.socket_path)
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
  
  @@amqp_channel : ::AMQP::Client::Channel? = nil
  
  extend Getters
end