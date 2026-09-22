getter windows : Array(JSON::Any)
getter raw_pixels : Slice(UInt8)
getter timestamp : Int64

getter width : Int32
getter height : Int32

def initialize(@windows, @raw_pixels, @timestamp, @width, @height)
end
