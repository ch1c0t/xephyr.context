require "./xephyr.save_screenshots_to/*"

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
require "../screenshot"

if ARGV.empty?
  puts "Usage: DISPLAY_TARGET=\":10\" ./bin/xephyr.save_screenshots_to <target_directory>"
  exit 1
end

output_dir = ARGV[0]

context = XephyrContext.new(Global.display, Global.amqp_channel)

puts " [Boot] Snapshot engine synchronized with Display #{Global.display}."
puts " [Active] Tracking workspace mutations... Images will dump into #{output_dir}/"

context.each_mutation do |state|
  begin
    Screenshot.new(state).save_to(output_dir)
    puts "  [SAVED] #{state.timestamp} ──► #{output_dir}/"
  rescue ex : Exception
    puts "  [Recorder Error] Failed writing image context payload: #{ex.message}"
  end
end

sleep
