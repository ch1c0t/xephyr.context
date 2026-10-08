def run : Nil
  supervisor = Supervisor.new
  display = supervisor.start

  begin
    wait_for_word(display)
  ensure
    supervisor.stop
  end
end

private def wait_for_word(display : String) : Nil
  context = XephyrContext.new(display, Global.amqp_channel)
  context.wait_until "close"
end