fun TessVersion : LibC::Char*

fun TessBaseAPICreate : TessBaseAPI
fun TessBaseAPIDelete(handle : TessBaseAPI) : Nil

fun TessBaseAPIInit3(
  handle : TessBaseAPI,
  datapath : LibC::Char*,
  language : LibC::Char*
) : LibC::Int

fun TessBaseAPISetImage(
  handle : TessBaseAPI,
  imagedata : UInt8*,
  width : LibC::Int,
  height : LibC::Int,
  bytes_per_pixel : LibC::Int,
  bytes_per_line : LibC::Int
) : Nil

fun TessBaseAPIGetUTF8Text(handle : TessBaseAPI) : LibC::Char*
fun TessDeleteText(text : LibC::Char*) : Nil
fun TessBaseAPIEnd(handle : TessBaseAPI) : Nil
