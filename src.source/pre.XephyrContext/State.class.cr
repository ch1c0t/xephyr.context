getter windows : Array(JSON::Any)
getter raw_pixels : Slice(UInt8)
getter timestamp : Int64

def initialize(@windows, @raw_pixels, @timestamp)
end
