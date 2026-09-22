# Absolute screen resolution bounds matching your Xephyr canvas setup
WIDTH  = 1920
HEIGHT = 1080

def initialize(@state : XephyrContext::State)
end

# =========================================================================
# HIGH-PERFORMANCE PIXEL EXPORT TO A TARGET DIRECTORY
# =========================================================================
def save_to(dir : String) : Nil
  # 1. Defensive Guard: Ensure the requested directory branch exists on disk
  FileUtils.mkdir_p(dir)

  # 2. Build our explicit timestamped filename string inside that directory path
  path = File.join(dir, "frame_#{@state.timestamp}.png")

  canvas = StumpyPNG::Canvas.new(WIDTH, HEIGHT)
  raw_bytes = @state.raw_pixels

  HEIGHT.times do |y|
    WIDTH.times do |x|
      # ZPixmap sequential mapping lookup [B, G, R, A]
      pixel_offset = (y * WIDTH + x) * 4
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

  # Write out the physical PNG binary
  StumpyPNG.write(canvas, path)
end
