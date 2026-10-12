property windows : Array(X11::Window)
property canvas : X11::Image

def initialize(@windows, @canvas)
end

def summarize
  Log.debug { "Context summary payload" }
  Log.debug { "Total windows found: #{@windows.size}" }
  @windows.each_with_index do |win, i|
    Log.trace { "Window[#{i}] ID=#{win.id} title=#{win.title.inspect}" }
  end

  if img = @canvas
    Log.debug { "Canvas profile: #{img.width}x#{img.height} @ #{img.color_depth}-bit depth" }
  end
end
