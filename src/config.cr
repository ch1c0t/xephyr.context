module Config
  # 1. Thread-safe cached configuration class variables
  @@socket_path : String = begin
    path = ENV["LAVINMQ_AMQP_UNIXSOCKET"]?
    raise "Missing critical environment configuration variable: LAVINMQ_AMQP_UNIXSOCKET" if path.nil?
    path
  end
  
  @@display : String = ENV.fetch("DISPLAY_TARGET", ":10")
  @@display_number : String = @@display.delete(':')
  
  # 2. Clean class property accessors
  def self.socket_path : String
    @@socket_path
  end
  
  def self.display : String
    @@display
  end
  
  def self.display_number : String
    @@display_number
  end
end