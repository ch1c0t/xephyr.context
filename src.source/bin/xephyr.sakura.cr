require "../global"
require "../xephyr_context"

DISPLAY_COMMAND = "xephyr-run"
CONTEXT_COMMAND = "./bin/xephyr.context"
KILL_COMMAND = "xephyr-kill"
WORD = "close"

def display_from_xephyr_run : String
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

def kill_display(display : String) : Nil
  status = Process.run(
    KILL_COMMAND,
    [display],
    error: Process::Redirect::Inherit
  )

  raise "xephyr-kill failed for #{display}: #{status}" unless status.success?
end

display = display_from_xephyr_run
context_process = nil.as(Process?)
killed = false

begin
  context_process = Process.new(
    CONTEXT_COMMAND,
    env: {"DISPLAY_TARGET" => display},
    output: Process::Redirect::Inherit,
    error: Process::Redirect::Inherit
  )

  context = XephyrContext.new(display, Global.amqp_channel)
  context.wait_until WORD

  context_process.try(&.terminate)
  kill_display(display)
  killed = true
ensure
  context_process.try(&.terminate)
  kill_display(display) unless killed
end
