require "amqp-client"
require "global-amqp_channel"

module Global
  module Getters
    def display : String
      @@display
    end
    
    def display_number : String
      @@display_number
    end
    
    def interval : Time::Span
      @@interval
    end
  end

  @@display : String = ENV.fetch("DISPLAY_TARGET", ":10")
  @@display_number : String = @@display.delete(':')
  @@interval : Time::Span = ENV.fetch("PULL_INTERVAL", "1000").to_i.milliseconds
  
  extend Getters
end