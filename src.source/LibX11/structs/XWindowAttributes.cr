x : LibC::Int
y : LibC::Int
width : LibC::Int
height : LibC::Int
border_width : LibC::Int
depth : LibC::Int
visual : Void*
root : Window
class_enum : LibC::Int
bit_gravity : LibC::Int
win_gravity : LibC::Int
backing_store : LibC::Int
backing_planes : LibC::ULong
backing_pixel : LibC::ULong
save_under : LibC::Int       # Maps to C Bool (usually int)
colormap : LibC::ULong       # Maps to Colormap XID
map_installed : LibC::Int    # Maps to C Bool
map_state : LibC::Int        # IsUnmapped, IsUnviewable, IsViewable
all_event_masks : LibC::Long
your_event_mask : LibC::Long
do_not_propagate_mask : LibC::Long
override_redirect : LibC::Int # Maps to C Bool
screen : Void*               # Pointer to Screen structure
