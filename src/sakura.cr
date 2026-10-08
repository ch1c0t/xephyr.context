class Sakura
  DISPLAY_COMMAND = "xephyr-run"
  CONTEXT_COMMAND = "./bin/xephyr.context"

  @display_process : Process?
  @context_process : Process?

  def initialize
    @display_process = nil
    @context_process = nil
  end

  def run : Nil
    install_termination_handler
    display = start_display
    @context_process = start_context(display)

    begin
      wait_for_word(display)
    ensure
      cleanup
    end
  end

  private def install_termination_handler : Nil
    Process.on_terminate do
      cleanup
      Process.exit
    end
  end

  private def start_display : String
    @display_process = Process.new(
      "setsid",
      [DISPLAY_COMMAND, "sakura"],
      output: Process::Redirect::Pipe,
      error: Process::Redirect::Inherit
    )

    display = @display_process.not_nil!.output.gets.try(&.strip)
    raise "xephyr-run did not return a display" unless display

    @display_process.not_nil!.wait
    display
  end

  private def start_context(display : String) : Process
    Process.new(
      CONTEXT_COMMAND,
      env: {"DISPLAY_TARGET" => display},
      output: Process::Redirect::Inherit,
      error: Process::Redirect::Inherit
    )
  end

  private def wait_for_word(display : String) : Nil
    context = XephyrContext.new(display, Global.amqp_channel)
    context.wait_until "close"
  end

  private def cleanup : Nil
    terminate(@context_process)
    terminate_process_group(@display_process)
  end

  private def terminate(process : Process?) : Nil
    process.try do |current|
      current.terminate unless current.terminated?
    rescue RuntimeError
    end
  end

  private def terminate_process_group(process : Process?) : Nil
    process.try do |current|
      pid = current.pid
      Process.signal(Signal::TERM, -pid)
      sleep 100.milliseconds
      Process.signal(Signal::KILL, -pid)
    rescue RuntimeError
    end
  end
end
