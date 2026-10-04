require "../global"
require "../xephyr_context"

DISPLAY_COMMAND = "xephyr-run"
CONTEXT_COMMAND = "xephyr.context"
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

display = display_from_xephyr_run
context_process = nil.as(Process?)

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
  Process.run(KILL_COMMAND, [display], error: Process::Redirect::Inherit)
ensure
  context_process.try(&.terminate)
  Process.run(KILL_COMMAND, [display], error: Process::Redirect::Inherit) if display
end
