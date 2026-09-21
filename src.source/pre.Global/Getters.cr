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
