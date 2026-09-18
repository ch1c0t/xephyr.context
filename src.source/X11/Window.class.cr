getter id : LibX11::Window

def initialize(@id : LibX11::Window, @display : X11::Display)
end

include Getters
include SelectInput
