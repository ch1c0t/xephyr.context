require "../global"
require "../xephyr_context"

context = XephyrContext.new(Global.display, Global.amqp_channel)

puts " [Boot] Agent environment link established smoothly."

context.each_mutation do |state|
  puts "\n--- [Agent Sensed Workspace Mutation] ---"
  puts "Timestamp Reference : #{state.timestamp}"
  puts "Active App Containers: #{state.windows.size} elements found."
  puts "Decompressed Pixels : #{state.raw_pixels.size} bytes loaded dynamically in memory."
end

sleep
