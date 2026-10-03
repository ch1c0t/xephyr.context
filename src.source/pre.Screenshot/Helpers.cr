private def rgb_pixel(offset : Int) : {UInt8, UInt8, UInt8}
  raw_bytes = @state.raw_pixels

  {
    raw_bytes[offset + 2], # R
    raw_bytes[offset + 1], # G
    raw_bytes[offset]      # B
  }
end
