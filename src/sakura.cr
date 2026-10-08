class Sakura::Supervisor
  DISPLAY_COMMAND = "xephyr-run"
  CONTEXT_COMMAND = "./bin/xephyr.context"
  KILL_COMMAND = "xephyr-kill"

  @display_process : Process?
  @context_process : Process?
  @display : String?

  def initialize
    @display_process = nil
    @context_process = nil
    @display = nil
  end

  def start : String
    @display_process = Process.new(
      DISPLAY_COMMAND,
      ["sakura"],
      output: Process::Redirect::Pipe,
      error: Process::Redirect::Inherit
    )

    @display = @display_process.not_nil!.output.gets.try(&.strip)
    raise "xephyr-run did not return a display" unless @display

    @context_process = Process.new(
      CONTEXT_COMMAND,
      env: {"DISPLAY_TARGET" => @display.not_nil!},
      output: Process::Redirect::Inherit,
      error: Process::Redirect::Inherit
    )

    @display.not_nil!
  end

  def stop : Nil
    terminate(@context_process)
    kill_display(@display)
  end

  private def terminate(process : Process?) : Nil
    process.try do |current|
      current.terminate unless current.terminated?
    rescue RuntimeError
    end
  end

  private def kill_display(display : String?) : Nil
    display.try do |current|
      Process.run(KILL_COMMAND, [current], error: Process::Redirect::Inherit)
    rescue RuntimeError
    end
  end
end

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
