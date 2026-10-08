class Sakura
  class Supervisor
    DISPLAY_COMMAND = "xephyr-run"
    KILL_COMMAND = "xephyr-kill"
    CONTEXT_COMMAND = "./bin/xephyr.context"

    getter display : String?

    @display_process : Process?
    @context_process : Process?
    @stopped : Bool

    def initialize
      @display = nil
      @display_process = nil
      @context_process = nil
      @stopped = false
      Process.on_terminate { stop; Process.exit }
    end

    def start : String
      @display = start_display
      @context_process = start_context(@display.not_nil!)
      @display.not_nil!
    end

    def stop : Nil
      return if @stopped
      @stopped = true
      terminate(@context_process)
      kill_display(@display)
    end

    private def start_display : String
      @display_process = Process.new(
        DISPLAY_COMMAND,
        ["sakura"],
        output: Process::Redirect::Pipe,
        error: Process::Redirect::Inherit
      )
      process = @display_process.not_nil!
      display = process.output.gets.try(&.strip)
      raise "xephyr-run did not return a display" unless display
      process.wait
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

    private def terminate(process : Process?) : Nil
      process.try { |current| current.terminate unless current.terminated? }
    rescue RuntimeError
    end

    private def kill_display(display : String?) : Nil
      return unless display
      Process.run(KILL_COMMAND, [display], error: Process::Redirect::Inherit)
    rescue RuntimeError
    end
  end

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
end