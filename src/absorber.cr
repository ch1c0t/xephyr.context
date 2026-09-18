class Absorber
  def initialize(@display : X11::Display)
  end
  
  def absorb(width : Int32 = 800, height : Int32 = 600) : X11::Context
    root = @display.root_window
  
    root_ret = uninitialized LibX11::Window
    parent_ret = uninitialized LibX11::Window
    nchildren = uninitialized LibC::UInt
    children_ptr = uninitialized LibX11::Window*
  
    status = LibX11.XQueryTree(@display.handle, root, pointerof(root_ret), pointerof(parent_ret), pointerof(children_ptr), pointerof(nchildren))
    
    windows = [] of X11::Window
    if status != 0 && !children_ptr.null?
      Slice.new(children_ptr, nchildren.to_i32).each do |id|
        # Pass the global parent display handle straight into the window
        windows << X11::Window.new(id, @display)
      end
      LibX11.XFree(children_ptr.as(Void*))
    end
  
    canvas = X11::Image.new(@display, root, width, height)
  
    return X11::Context.new(windows, canvas)
  end
  
  def summarize(width : Int32 = 800, height : Int32 = 600) : Nil
    context = absorb(width, height)
    begin
      context.summarize
    ensure
      # Guaranteed execution block to ensure zero memory leaks
      context.canvas.try(&.destroy)
    end
  end
end