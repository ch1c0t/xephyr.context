require "file_utils"
require "stumpy_png"

class Screenshot
  def initialize(@state : XephyrContext::State)
  end
  
  def save_to(dir : String) : Nil
    FileUtils.mkdir_p(dir)
    path = File.join(dir, "frame_#{@state.timestamp}.png")
  
    width = @state.width
    height = @state.height
  
    canvas = StumpyPNG::Canvas.new(width, height)
    raw_bytes = @state.raw_pixels
  
    height.times do |y|
      width.times do |x|
        # https://share.google/aimode/QgWBqs9YsQWg2fHVX
        # ZPixmap sequential mapping lookup [B, G, R, A]
        pixel_offset = (y * width + x) * 4
        break if pixel_offset + 3 >= raw_bytes.size
  
        b = raw_bytes[pixel_offset]
        g = raw_bytes[pixel_offset + 1]
        r = raw_bytes[pixel_offset + 2]
  
        # https://share.google/aimode/62pRped5KHu43slrQ
        # Explicitly force full opacity (255) instead of reading raw_bytes[3]
        a = 255_u8
  
        color = StumpyPNG::RGBA.from_rgba_n(r, g, b, a, 8)
        canvas[x, y] = color
      end
    end
  
    StumpyPNG.write(canvas, path)
  end
end