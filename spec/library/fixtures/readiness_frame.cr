class ReadinessFrame
  getter width : Int32
  getter height : Int32
  getter pixels : Bytes

  def initialize
    text = "READY"
    scale = 18
    margin_x = 72
    margin_y = 48

    @width = text.size * 6 * scale + 2 * margin_x
    @height = 7 * scale + 2 * margin_y
    @pixels = Slice(UInt8).new(@width * @height * 4, 255_u8)

    glyphs = {
      'R' => ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
      'E' => ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
      'A' => ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
      'D' => ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
      'Y' => ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    }

    text.each_char_with_index do |character, character_index|
      glyphs[character].each_with_index do |line, row|
        line.each_char_with_index do |on, column|
          next unless on == '1'

          scale.times do |dy|
            scale.times do |dx|
              x = margin_x + character_index * 6 * scale + column * scale + dx
              y = margin_y + row * scale + dy
              pixel = (y * @width + x) * 4
              @pixels[pixel] = 0_u8
              @pixels[pixel + 1] = 0_u8
              @pixels[pixel + 2] = 0_u8
            end
          end
        end
      end
    end
  end
end
