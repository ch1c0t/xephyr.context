getter display : String
getter context : XephyrContext

def initialize(@display : String, channel : ::AMQP::Client::Channel)
  @context = XephyrContext.new(display, channel)
end

def watch(
  ocr : Bool = false,
  save_dir : String? = nil,
  count : Int32? = nil
) : Nil
  recognizer = XephyrContext::TextRecognizer.new if ocr
  seen = 0
  done = Channel(Nil).new(1)

  begin
    @context.each_mutation do |state|
      seen += 1
      report(state, recognizer, save_dir)

      if count && seen >= count
        done.send(nil)
      end
    end

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

  if recognizer
    puts "  [OCR] #{recognizer.recognize(state).strip.inspect}"
  end

  if save_dir
    Screenshot.new(state).save_to(save_dir)
    puts "  [SAVED] #{File.join(save_dir, "frame_#{state.timestamp}.png")}"
  end
end
