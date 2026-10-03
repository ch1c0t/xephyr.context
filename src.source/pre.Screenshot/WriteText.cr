private def write_text(dir : String) : Nil
  path = File.join(dir, "frame_#{@state.timestamp}.txt")
  File.write(path, recognize_text)
end

private def recognize_text : String
  pixels = grayscale_pixels
  text_recognizer.recognize(pixels, @state.width, @state.height)
end

private def grayscale_pixels : Slice(UInt8)
  raw_bytes = @state.raw_pixels
  expected_size = @state.width.to_i64 * @state.height.to_i64 * 4
  raise "Unexpected framebuffer size: #{raw_bytes.size}, expected at least #{expected_size}" if raw_bytes.size < expected_size

  pixels = Slice(UInt8).new(@state.width * @state.height)
  offset = 0

  @state.height.times do |y|
    @state.width.times do |x|
      pixel_offset = (y * @state.width + x) * 4
      r, g, b = rgb_pixel(pixel_offset)

      # X11 ZPixmap gives us BGRA; OCR consumes 8-bit grayscale.
      pixels[offset] = ((r.to_i * 299 + g.to_i * 587 + b.to_i * 114) // 1000).to_u8
      offset += 1
    end
  end

  pixels
end
