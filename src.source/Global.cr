@@display : String = ENV.fetch("DISPLAY_TARGET", ":10")
@@display_number : String = @@display.delete(':')
@@interval : Time::Span = ENV.fetch("PULL_INTERVAL", "1000").to_i.milliseconds

extend Getters
