HELP_MESSAGE = <<-S
xephyr.context.inspect watches screen states published by xephyr.context.

It needs the same environment as xephyr.context:

  DISPLAY_TARGET=":10"
  LAVINMQ_AMQP_UNIXSOCKET="$HOME/.local/share/lavinmq/amqp.sock"

Usage:

  DISPLAY_TARGET=":10" xephyr.context.inspect

Options:

  --watch
      Watch live screen mutations. This is the default.

  --replay OFFSET
      Replay screen mutations starting from OFFSET. For example, use
      "first" to inspect the oldest retained mutation.

  --once
      Inspect the next screen mutation and exit.

  --count N
      Inspect N screen mutations and exit.

  --ocr
      Run Tesseract OCR on every inspected screen state.

  --save-dir DIR
      Save every inspected screen state as a PNG in DIR. When combined
      with --ocr, also save the recognized text as
      frame_<timestamp>.txt alongside frame_<timestamp>.png.

  --help
      Show this help.

Examples:

  DISPLAY_TARGET=":10" xephyr.context.inspect

  DISPLAY_TARGET=":10" xephyr.context.inspect --ocr

  DISPLAY_TARGET=":10" xephyr.context.inspect --once --ocr

  DISPLAY_TARGET=":10" xephyr.context.inspect --count 10 --save-dir /tmp/xephyr

  DISPLAY_TARGET=":10" xephyr.context.inspect --replay first --ocr

  DISPLAY_TARGET=":10" xephyr.context.inspect --replay first --count 10 --save-dir /tmp/grml-debug

  DISPLAY_TARGET=":10" xephyr.context.inspect --watch --ocr --save-dir /tmp/grml

Each mutation reports:

  - timestamp
  - framebuffer dimensions
  - raw pixel byte count
  - number of spatial windows

With --ocr, the recognized guest-screen text is printed.

With --save-dir, the exact framebuffer received from the xephyr.context
stream is written as frame_<timestamp>.png.

With --ocr --save-dir, the OCR result is also written as
frame_<timestamp>.txt, using the same timestamp as the image.

With --replay, mutations are read from the requested stream offset instead
of starting with the live stream.
S

def print_help
  puts HELP_MESSAGE
end
