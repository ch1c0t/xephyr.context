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
