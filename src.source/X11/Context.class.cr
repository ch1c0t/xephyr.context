property windows : Array(X11::Window)
property canvas : X11::Image

def initialize(@windows, @canvas)
end

def summarize
  puts "\n--- Context Summary Payload ---"
  puts "Total Windows Found: #{@windows.size}"
  @windows.each_with_index do |win, i|
    puts "  [#{i}] ID: #{win.id} | Title: \"#{win.title}\""
  end

  if img = @canvas
    puts "Canvas Profile: #{img.width}x#{img.height} @ #{img.color_depth}-bit depth"
  end
end
