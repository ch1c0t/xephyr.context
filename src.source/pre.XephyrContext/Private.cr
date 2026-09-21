private def build_state_snapshot(payload : JSON::Any) : State
  timestamp = payload["timestamp"].as_i64
  raw_pixels = inflate_canvas_bytes(payload["data"].as_s)

  State.new(
    windows:    @current_spatial_data, # Blends from the active spatial background cache
    raw_pixels: raw_pixels,
    timestamp:  timestamp
  )
end

private def parse_spatial_windows(payload : JSON::Any) : Array(JSON::Any)
  payload["windows"]?.try(&.as_a) || [] of JSON::Any
rescue Exception
  [] of JSON::Any
end

private def inflate_canvas_bytes(base64_string : String) : Slice(UInt8)
  compressed_bytes = Base64.decode(base64_string)
  decompressed_io = IO::Memory.new
  IO.copy(Compress::Deflate::Reader.new(IO::Memory.new(compressed_bytes)), decompressed_io)
  decompressed_io.to_slice
end
