alias Window = LibC::ULong
alias Drawable = LibC::ULong

type Display = Void*
type Visual = Void*

# Event Mask Flags
ExposureMask    = 1_i64 << 15
StructureNotifyMask = 1_i64 << 17
SubstructureNotifyMask = 1_i64 << 18

# Event Codes
Expose          = 12
ConfigureNotify = 22
