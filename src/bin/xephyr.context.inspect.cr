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

unless count.nil? || count > 0
  STDERR.puts "--count must be greater than zero."
  exit 1
end

if save_dir
  FileUtils.mkdir_p(save_dir)
end

puts "[Boot] Inspecting Xephyr display #{Global.display}."
puts "[Mode] OCR enabled." if ocr
puts "[Mode] Saving screenshots to #{save_dir}." if save_dir

inspector = XephyrContext::Inspector.new(Global.display, Global.amqp_channel)
inspector.watch(ocr: ocr, save_dir: save_dir, count: count)
