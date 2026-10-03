private def write_text(dir : String) : Nil
  path = File.join(dir, "frame_#{@state.timestamp}.txt")
  File.write(path, recognize_text)
end

private def recognize_text : String
  pixels = grayscale_pixels
  text_recognizer.recognize(pixels, @state.width, @state.height)
end
