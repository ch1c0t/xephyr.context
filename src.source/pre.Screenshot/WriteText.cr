private def write_text(dir : String) : Nil
  path = File.join(dir, "frame_#{@state.timestamp}.txt")
  File.write(path, recognize_text)
end

private def recognize_text : String
  pixels = grayscale_pixels

  # The CLI adapter needs a PGM image; LibTesseract can consume the same
  # grayscale pixels directly.
  input = IO::Memory.new
  input << "P5\n#{@state.width} #{@state.height}\n255\n"
  input.write(pixels)
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

  output.to_s
end
