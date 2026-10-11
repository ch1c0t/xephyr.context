def initialize(@language : String = "eng")
  @closed = false
  @api = LibTesseract.TessBaseAPICreate
  raise "Tesseract failed to create API" if @api.null?

  status = LibTesseract.TessBaseAPIInit3(
    @api,
    Pointer(LibC::Char).null,
    @language.to_unsafe.as(LibC::Char*)
  )

  if status != 0
    @closed = true
    LibTesseract.TessBaseAPIDelete(@api)
    raise "Tesseract failed to initialize for language #{@language} (exit code #{status})"
  end
end

def recognize(
  state : XephyrContext::State,
  region : XephyrContext::ScreenRegion = XephyrContext::ScreenRegion.full_screen
) : String
  pixels, width, height = grayscale_pixels(state, region)
  recognize(pixels, width, height)
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

def close
  return if @closed

  @closed = true
  LibTesseract.TessBaseAPIEnd(@api)
  LibTesseract.TessBaseAPIDelete(@api)
end

def finalize
  close
end

private def grayscale_pixels(
  state : XephyrContext::State,
  region : XephyrContext::ScreenRegion
) : Tuple(Slice(UInt8), Int32, Int32)
  x0 = (region.x * state.width).to_i.clamp(0, state.width - 1)
  y0 = (region.y * state.height).to_i.clamp(0, state.height - 1)
  x1 = ((region.x + region.width) * state.width).ceil.to_i.clamp(x0 + 1, state.width)
  y1 = ((region.y + region.height) * state.height).ceil.to_i.clamp(y0 + 1, state.height)
  width = x1 - x0
  height = y1 - y0
  pixels = Slice(UInt8).new(width * height)
  offset = 0

  y0.upto(y1 - 1) do |y|
    x0.upto(x1 - 1) do |x|
      pixel = (y * state.width + x) * 4
      b = state.raw_pixels[pixel]
      g = state.raw_pixels[pixel + 1]
      r = state.raw_pixels[pixel + 2]
      pixels[offset] = ((r.to_i * 299 + g.to_i * 587 + b.to_i * 114) // 1000).to_u8
      offset += 1
    end
  end

  {pixels, width, height}
end
