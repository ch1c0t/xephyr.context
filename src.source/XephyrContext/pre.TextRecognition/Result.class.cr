getter state : State
getter text : String
getter region : ScreenRegion
getter duration : Time::Span
getter error : String?

def initialize(
  @state : State,
  @text : String,
  @region : ScreenRegion,
  @duration : Time::Span,
  @error : String? = nil
)
end

def timestamp : Int64
  @state.timestamp
end

def success? : Bool
  @error.nil?
end
