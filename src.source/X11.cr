# https://share.google/aimode/ve4pLYNnk1fbjQITm
# https://maltsev.space/blog/011-practical-bitwise-tricks-in-everyday-code
# https://share.google/aimode/dMymIVrGGWVlg3ZLE
enum EventType : Int64
  KeyPressMask             = 1_i64 << 0
  KeyReleaseMask           = 1_i64 << 1
  ButtonPressMask          = 1_i64 << 2
  ButtonReleaseMask        = 1_i64 << 3
  PointerMotionMask        = 1_i64 << 6
  ExposureMask             = 1_i64 << 15
  StructureNotifyMask      = 1_i64 << 17
  SubstructureNotifyMask   = 1_i64 << 18
  SubstructureRedirectMask = 1_i64 << 19
  FocusChangeMask          = 1_i64 << 23
end

# =========================================================================
# THE COMBINED CONSTANT: Merges every critical observation mask together
# =========================================================================
ALL_EVENTS_MASK = EventType::KeyPressMask.value             |
                  EventType::KeyReleaseMask.value           |
                  EventType::ButtonPressMask.value          |
                  EventType::ButtonReleaseMask.value        |
                  EventType::PointerMotionMask.value        |
                  EventType::ExposureMask.value             |
                  EventType::StructureNotifyMask.value      |
                  EventType::SubstructureNotifyMask.value   |
                  EventType::SubstructureRedirectMask.value |
                  EventType::FocusChangeMask.value
