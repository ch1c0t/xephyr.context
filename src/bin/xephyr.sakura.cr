require "./xephyr.sakura/*"

VERSION = "0.0.0"

case ARGV.size
when 1
  case ARGV[0]
  when "-v", "version", "--version"
    puts VERSION
    exit
  when "-h", "help", "--help"
    print_help
    exit
  end
end

require "../global"
require "../xephyr_context"

DISPLAY_COMMAND = "xephyr-run"
CONTEXT_COMMAND = "xephyr.context"
KILL_COMMAND = "xephyr-kill"
WORD = "close"

def grayscale_pixels(state : XephyrContext::State) : Slice(UInt8)
  pixels = Slice(UInt8).new(state.width * state.height)
  offset = 0

  state.height.times do |y|
    state.width.times do |x|
      pixel = (y * state.width + x) * 4
      b = state.raw_pixels[pixel]
      g = state.raw_pixels[pixel + 1]
      r = state.raw_pixels[pixel + 2]

      pixels[offset] = ((r.to_i * 299 + g.to_i * 587 + b.to_i * 114) // 1000).to_u8
      offset += 1
    end
  end

  pixels
end

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
text_recognizer = XephyrContext::TextRecognizer.new
context = nil.as(XephyrContext?)

begin
  context_process = Process.new(
    CONTEXT_COMMAND,
    env: {"DISPLAY_TARGET" => display},
    output: Process::Redirect::Inherit,
    error: Process::Redirect::Inherit
  )

  context = XephyrContext.new(display, Global.amqp_channel)

  context.each_mutation do |state|
    text = text_recognizer.recognize(
      grayscale_pixels(state),
      state.width,
      state.height
    )

    next unless text.downcase.includes?(WORD)

    context_process.try(&.terminate)
    Process.run(KILL_COMMAND, [display], error: Process::Redirect::Inherit)
    exit
  rescue ex : Exception
    STDERR.puts " [Sakura Error] #{ex.message}"
  end

  sleep
ensure
  context_process.try(&.terminate)
  Process.run(KILL_COMMAND, [display], error: Process::Redirect::Inherit) if display
end
