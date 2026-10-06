require "../global"
require "../xephyr_context"
require "../screenshot"

options = ARGV.dup

if options.includes?("--help") || options.includes?("-h")
  puts File.read("#{__DIR__}/xephyr.context.inspect/help")
  exit
end

ocr = options.delete("--ocr")
once = options.delete("--once")
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
  warn "Unknown arguments: #{options.join(" ")}"
  warn "Use --help for usage."
  exit 1
end

unless count.nil? || count > 0
  warn "--count must be greater than zero."
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
