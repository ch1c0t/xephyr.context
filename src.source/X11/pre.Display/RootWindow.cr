def root_window : LibX11::Window
  LibX11.XDefaultRootWindow(@handle)
end

def root_window_object : X11::Window
  X11::Window.new(root_window, self)
end
