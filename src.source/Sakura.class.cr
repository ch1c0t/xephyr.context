class Sakura
  def initialize
    @supervisor = Sakura::Supervisor.new
  end

  def run : Nil
    install_termination_handler
    display = @supervisor.start

    begin
      wait_for_word(display)
    ensure
      @supervisor.stop
    end
  end

  private def install_termination_handler : Nil
    Process.on_terminate do
      @supervisor.stop
      Process.exit
    end
  end

  private def wait_for_word(display : String) : Nil
    context = XephyrContext.new(display, Global.amqp_channel)
    context.wait_until "close"
  end
end
