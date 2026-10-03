def initialize(@state : XephyrContext::State, @text_recognizer : XephyrContext::TextRecognizer? = nil)
end

def save_to(dir : String, save_image : Bool = true, save_text : Bool = false) : Nil
  FileUtils.mkdir_p(dir)

  write_image(dir) if save_image
  write_text(dir) if save_text
end

private def text_recognizer : XephyrContext::TextRecognizer
  @text_recognizer ||= XephyrContext::TextRecognizer.new
end

include WriteImage
include WriteText
include Helpers
