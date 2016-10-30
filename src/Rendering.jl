function init_window(engine::Engine)
	GLFW.Init()
	GLFW.WindowHint(GLFW.DEPTH_BITS, 24)
	GLFW.WindowHint(GLFW.STENCIL_BITS, 8)
	GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
	GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 3)
	engine.window = GLFW.CreateWindow(640, 480, "GamEn.jl")
	GLFW.MakeContextCurrent(engine.window)
	GLFW.SwapInterval(0)
end

function done_window(engine::Engine)
	GLFW.Terminate()
end

function init_viewport(engine::Engine)
	set_viewport(engine, GLFW.GetFramebufferSize(engine.window)...)
	GLFW.SetFramebufferSizeCallback(engine.window, (win::GLFW.Window, width::Cint, height::Cint) -> set_viewport(engine, width, height))
end

function set_viewport(engine::Engine, width::Integer, height::Integer)
	ModernGL.glViewport(0, 0, width, height)

	call_event(engine, :viewport, width, height)
end
