require "file_utils"
require "stumpy_png"

class Screenshot
  module Helpers
    private def rgb_pixel(offset : Int) : {UInt8, UInt8, UInt8}
      raw_bytes = @state.raw_pixels
    
      {
        raw_bytes[offset + 2], # R
        raw_bytes[offset + 1], # G
        raw_bytes[offset]      # B
      }
    end
  end

  module WriteImage
    private def write_image(dir : String) : Nil
      path = File.join(dir, "frame_#{@state.timestamp}.png")
    
      width = @state.width
      height = @state.height
    
      canvas = StumpyPNG::Canvas.new(width, height)
      raw_bytes = @state.raw_pixels
    
      # https://share.google/aimode/QgWBqs9YsQWg2fHVX
      # ZPixmap sequential mapping lookup [B, G, R, A]
      height.times do |y|
        width.times do |x|
          pixel_offset = (y * width + x) * 4
          break if pixel_offset + 3 >= raw_bytes.size
    
          r, g, b = rgb_pixel(pixel_offset)
    
          # https://share.google/aimode/62pRped5KHu43slrQ
          # Explicitly force full opacity (255)
          a = 255_u8
    
          color = StumpyPNG::RGBA.from_rgba_n(r, g, b, a, 8)
          canvas[x, y] = color
        end
      end
    
      StumpyPNG.write(canvas, path)
    end
  end

  module WriteText
    private def write_text(dir : String) : Nil
      path = File.join(dir, "frame_#{@state.timestamp}.txt")
    
      input = IO::Memory.new
      input << "P5\n#{@state.width} #{@state.height}\n255\n"
    
      raw_bytes = @state.raw_pixels
      expected_size = @state.width.to_i64 * @state.height.to_i64 * 4
      raise "Unexpected framebuffer size: #{raw_bytes.size}, expected at least #{expected_size}" if raw_bytes.size < expected_size
    
      @state.height.times do |y|
        @state.width.times do |x|
          pixel_offset = (y * @state.width + x) * 4
          r, g, b = rgb_pixel(pixel_offset)
    
          # X11 ZPixmap gives us BGRA. Tesseract receives a grayscale PGM.
          gray = ((r.to_i * 299 + g.to_i * 587 + b.to_i * 114) // 1000).to_u8
          input.write_byte(gray)
        end
      end
      input.rewind
    
      output = IO::Memory.new
      error = IO::Memory.new
    
      status = Process.run(
        "tesseract",
        ["stdin", "stdout"],
        input: input,
        output: output,
        error: error
      )
    
      unless status.success?
        details = error.to_s
        raise "Tesseract failed with exit code #{status.exit_code}: #{details}" unless details.empty?
        raise "Tesseract failed with exit code #{status.exit_code}"
      end
    
      File.write(path, output.to_s)
    end
  end

  def initialize(@state : XephyrContext::State)
  end
  
  def save_to(dir : String, save_image : Bool = true, save_text : Bool = false) : Nil
    FileUtils.mkdir_p(dir)
  
    write_image(dir) if save_image
    write_text(dir) if save_text
  end
  
  include WriteImage
  include WriteText
  include Helpers
end