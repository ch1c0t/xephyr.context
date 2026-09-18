# The @[Flags] annotation changes how this enum behaves under the hood
# https://share.google/aimode/ve4pLYNnk1fbjQITm
# https://maltsev.space/blog/011-practical-bitwise-tricks-in-everyday-code
@[Flags]
enum EventType : Int64
  Redraw       = 1_i64 << 15  # Maps to ExposureMask
  LayoutChange = 1_i64 << 17  # Maps to StructureNotifyMask
  ChildChange  = 1_i64 << 18  # Maps to SubstructureNotifyMask
end
