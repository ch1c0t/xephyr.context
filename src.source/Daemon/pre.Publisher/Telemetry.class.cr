getter current_hash : UInt64
@data : NamedTuple(routing_key: String, timestamp: Int64, windows: Array(JSON::Any))

# =========================================================================
# CLASS VARIABLE: Persists across the entire application lifetime process
# =========================================================================
@@last_hash : UInt64 = 0_u64

def initialize(windows : Array(X11::Window), routing_key : String)
  raw_windows = windows.map do |win|
    geom = win.geometry
    {
      "id"      => win.id.to_u64,
      "title"   => win.title,
      "spatial" => {
        "x" => geom[:x], "y" => geom[:y], "width" => geom[:width], "height" => geom[:height], "visible" => geom[:visible]
      }
    }
  end

  parsed_windows = JSON.parse(raw_windows.to_json).as_a
  @current_hash = parsed_windows.hash

  @data = {
    routing_key: routing_key,
    timestamp:   Time.local.to_unix,
    windows:     parsed_windows
  }
end

# 💡 NO ARGUMENTS NEEDED: Evaluates and updates history tracking state internally
def changed? : Bool
  if @current_hash != @@last_hash
    @@last_hash = @current_hash
    true
  else
    false
  end
end

def to_json : String
  @data.to_json
end
