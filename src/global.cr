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
  end

  @@display : String = ENV.fetch("DISPLAY_TARGET", ":10")
  @@display_number : String = @@display.delete(':')
  
  extend Getters
end