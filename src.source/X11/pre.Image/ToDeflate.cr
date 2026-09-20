# 💡 THINK: Squeezes raw framebuffer memory into a dense binary byte slice
def to_deflate : Slice(UInt8)
  img = @pointer.value
  buffer_size = img.bytes_per_line * img.height
  raw_pixel_bytes = Slice.new(img.data.as(UInt8*), buffer_size)

  compressed_io = IO::Memory.new

  Compress::Deflate::Writer.open(compressed_io) do |deflate|
    deflate.write(raw_pixel_bytes)
  end

  compressed_io.to_slice
end
