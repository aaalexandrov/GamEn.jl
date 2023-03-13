function init_window(engine::Engine, def::Dict{Symbol, Any})
	GLFW.Init()
	GLFW.WindowHint(GLFW.DEPTH_BITS, get(def, :depth_bits, 24))
	GLFW.WindowHint(GLFW.STENCIL_BITS, get(def, :stencil_bits, 8))
	local api
	if engine.api == :gl
		api = GLFW.OPENGL_API
	elseif engine.api == :gles
		api = GLFW.OPENGL_ES_API
	else
		api = GLFW.NO_API
	end
	GLFW.WindowHint(GLFW.CLIENT_API, api)
	ver = map(Int, get(def, :api_version, engine.apiVersion))
	GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, ver[1])
	GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, ver[2])
	winSize = map(Int, get(def, :window_size, [640, 480]))
	engine.window = GLFW.CreateWindow(winSize[1], winSize[2], get(def, :window_title, "GamEn.jl"))
	GLFW.MakeContextCurrent(engine.window)
	GLFW.SwapInterval(get(def, :swap_interval, 0))
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
