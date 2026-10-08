getter display : String
getter context : XephyrContext

def initialize(@display : String, channel : ::AMQP::Client::Channel)
  @context = XephyrContext.new(display, channel)
end

def watch(ocr : Bool = false, save_dir : String? = nil, count : Int32? = nil) : Nil
  inspect_stream(ocr, save_dir, count) do |block|
    @context.each_mutation(&block)
  end
end

def replay(offset : String, ocr : Bool = false, save_dir : String? = nil, count : Int32? = nil) : Nil
  inspect_stream(ocr, save_dir, count) do |block|
    @context.replay_mutations(offset, &block)
  end
end

private def inspect_stream(
  ocr : Bool,
  save_dir : String?,
  count : Int32?,
  &subscribe : Proc(Proc(XephyrContext::State, Nil), Nil)
) : Nil
  recognizer = XephyrContext::TextRecognizer.new if ocr
  seen = 0
  done = Channel(Nil).new(1)

  begin
    callback = Proc(XephyrContext::State, Nil).new do |state|
      seen += 1
      report(state, recognizer, save_dir)
      done.send(nil) if count && seen >= count
      nil
    end

    subscribe.call(callback)
    count ? done.receive : sleep
  ensure
    recognizer.try(&.finalize)
  end
end

private def report(
  state : XephyrContext::State,
  recognizer : XephyrContext::TextRecognizer?,
  save_dir : String?
) : Nil
  puts "[MUTATION] timestamp=#{state.timestamp} size=#{state.width}x#{state.height} " +
       "pixels=#{state.raw_pixels.size} windows=#{state.windows.size}"

  screenshot = Screenshot.new(state, recognizer)
  text = recognizer ? screenshot.recognized_text : nil
  puts "  [OCR] #{text.strip.inspect}" if text

  if save_dir
    screenshot.save_to(save_dir, save_image: true, save_text: !text.nil?)
    puts "  [SAVED] #{File.join(save_dir, "frame_#{state.timestamp}.png")}"
    puts "  [SAVED] #{File.join(save_dir, "frame_#{state.timestamp}.txt")}" if text
  end
end
