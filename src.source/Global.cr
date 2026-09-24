@@display : String = ENV.fetch("DISPLAY_TARGET", ":10")
@@display_number : String = @@display.delete(':')

extend Getters
