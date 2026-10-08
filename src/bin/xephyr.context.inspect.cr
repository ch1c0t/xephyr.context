require "./xephyr.context.inspect/*"

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

options = ARGV.dup

if options.includes?("--help") || options.includes?("-h")
  puts File.read("#{__DIR__}/xephyr.context.inspect/help")
  exit
end

ocr = !options.delete("--ocr").nil?
once = !options.delete("--once").nil?
replay_index = options.index("--replay")
replay_offset = replay_index.try do |index|
  options.delete_at(index)
  options.delete_at(index)
end
save_index = options.index("--save-dir")
save_dir = save_index.try do |index|
  options.delete_at(index)
  options.delete_at(index)
end

count = if once
  1
else
  count_index = options.index("--count")
  count_index.try do |index|
    options.delete_at(index)
    options.delete_at(index).to_i
  end
end

unless options.empty? || options == ["--watch"]
  STDERR.puts "Unknown arguments: #{options.join(" ")}"
  STDERR.puts "Use --help for usage."
  exit 1
end

if replay_offset && replay_offset.empty?
  STDERR.puts "--replay requires an offset."
  exit 1
end

unless count.nil? || count > 0
  STDERR.puts "--count must be greater than zero."
  exit 1
end

FileUtils.mkdir_p(save_dir) if save_dir

puts "[Boot] Inspecting Xephyr display #{Global.display}."
puts "[Mode] Replaying from #{replay_offset.inspect}." if replay_offset
puts "[Mode] OCR enabled." if ocr
puts "[Mode] Saving screenshots to #{save_dir}." if save_dir

inspector = XephyrContext::Inspector.new(Global.display, Global.amqp_channel)
if replay_offset
  inspector.replay(replay_offset, ocr: ocr, save_dir: save_dir, count: count)
else
  inspector.watch(ocr: ocr, save_dir: save_dir, count: count)
end
