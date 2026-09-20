# Returns true if this newly captured canvas differs from the previous historical frame
def changed? : Bool
  img = @pointer.value

  # ZERO-COPY MEMORY BRIDGE: Map the raw C heap array directly into a Crystal Slice
  buffer_size = img.bytes_per_line * img.height
  raw_slice = Slice.new(img.data.as(UInt8*), buffer_size)

  # Compute an ultra-fast hardware-accelerated block hash
  current_hash = raw_slice.hash

  if current_hash != @@last_hash
    @@last_hash = current_hash
    true
  else
    false
  end
end
