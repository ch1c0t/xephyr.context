def initialize(@language : String = "eng")
  @api = LibTesseract.TessBaseAPICreate
  raise "Tesseract failed to create API" if @api.null?

  status = LibTesseract.TessBaseAPIInit3(
    @api,
    Pointer(LibC::Char).null,
    @language.to_unsafe.as(LibC::Char*)
  )

  if status != 0
    LibTesseract.TessBaseAPIDelete(@api)
    raise "Tesseract failed to initialize for language #{@language} (exit code #{status})"
  end
end

def recognize(state : XephyrContext::State) : String
  recognize(grayscale_pixels(state), state.width, state.height)
end

def recognize(pixels : Slice(UInt8), width : Int32, height : Int32) : String
  LibTesseract.TessBaseAPISetImage(
    @api,
    pixels.to_unsafe,
    width,
    height,
    1,
    width
  )

  text = LibTesseract.TessBaseAPIGetUTF8Text(@api)
  raise "Tesseract returned no text" if text.null?

  begin
    String.new(text.as(UInt8*))
  ensure
    LibTesseract.TessDeleteText(text)
  end
end

def finalize
  LibTesseract.TessBaseAPIEnd(@api)
  LibTesseract.TessBaseAPIDelete(@api)
end

private def grayscale_pixels(state : XephyrContext::State) : Slice(UInt8)
  pixels = Slice(UInt8).new(state.width * state.height)
  offset = 0

  state.height.times do |y|
    state.width.times do |x|
      pixel = (y * state.width + x) * 4
      b = state.raw_pixels[pixel]
      g = state.raw_pixels[pixel + 1]
      r = state.raw_pixels[pixel + 2]
      pixels[offset] = ((r.to_i * 299 + g.to_i * 587 + b.to_i * 114) // 1000).to_u8
      offset += 1
    end
  end

  pixels
end
