DISPLAY_COMMAND = "xephyr-run"
CONTEXT_COMMAND = "./bin/xephyr.context"
KILL_COMMAND = "xephyr-kill"
WORD = "close"

def run : Nil
  display = start_display
  context_process = start_context(display)
  killed = false

  begin
    wait_for_word(display)

    terminate(context_process)
    kill_display(display)
    killed = true
  ensure
    terminate(context_process)
    kill_display(display) unless killed
  end
end

private def start_display : String
  process = Process.new(
    DISPLAY_COMMAND,
    ["sakura"],
    output: Process::Redirect::Pipe,
    error: Process::Redirect::Inherit
  )

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

private def wait_for_word(display : String) : Nil
  context = XephyrContext.new(display, Global.amqp_channel)
  context.wait_until WORD
end

private def terminate(process : Process?) : Nil
  process.try do |current|
    begin
      current.terminate
    rescue RuntimeError
      # The context may have exited after recognizing the word.
    end
  end
end

private def kill_display(display : String) : Nil
  status = Process.run(
    KILL_COMMAND,
    [display],
    error: Process::Redirect::Inherit
  )

  raise "xephyr-kill failed for #{display}: #{status}" unless status.success?
end
