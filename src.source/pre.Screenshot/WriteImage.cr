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
