private def serialize_canvas(canvas : X11::Image) : String
  compressed_bytes = canvas.to_deflate
  {
    "routing_key" => @canvas_queue.name,
    "timestamp"   => Time.local.to_unix,
    "bytes_size"  => compressed_bytes.size,
    "width"       => canvas.width,
    "height"      => canvas.height,
    "data"        => Base64.strict_encode(compressed_bytes)
  }.to_json
end
