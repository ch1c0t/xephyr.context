getter x : Float64
getter y : Float64
getter width : Float64
getter height : Float64

def initialize(@x : Float64, @y : Float64, @width : Float64, @height : Float64)
  raise "Region origin must be within 0.0..1.0" unless @x >= 0.0 && @x < 1.0 && @y >= 0.0 && @y < 1.0
  raise "Region dimensions must be positive" unless @width > 0.0 && @height > 0.0
  raise "Region must fit within the screen" unless @x + @width <= 1.0 && @y + @height <= 1.0
end

def self.full_screen : ScreenRegion
  new(0.0, 0.0, 1.0, 1.0)
end

def self.top_fourth : ScreenRegion
  new(0.0, 0.0, 1.0, 0.25)
end

def self.bottom_tenth : ScreenRegion
  new(0.0, 0.9, 1.0, 0.1)
end

def self.from_symbol(symbol : Symbol) : ScreenRegion
  case symbol
  when :full_screen  then full_screen
  when :top_fourth   then top_fourth
  when :bottom_tenth then bottom_tenth
  else
    raise ArgumentError.new("Unknown screen region: #{symbol.inspect}")
  end
end
