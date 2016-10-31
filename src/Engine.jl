type Engine
	renderer::GRU.Renderer
	defs::Dict{Symbol, Any}
	dataPath::String
	assets::Dict{Symbol, Any}
	events::Dict{Symbol, Vector{Function}}
	shouldClose::Bool
	timePrev::Float64
	timeNow::Float64
	window::GLFW.Window

	function Engine(dataPath::String)
		now = time()
		new(GRU.Renderer(), Dict{Symbol, Any}(), dataPath, Dict{Symbol, Any}(), Dict{Symbol, Vector{Function}}(), false, now, now)
	end
end

function init(engine::Engine)
	init_window(engine)
	GRU.init(engine.renderer)
	FTFont.init()
	GLHelper.gl_info()
end

function done(engine::Engine)
	while !isempty(engine.assets)
		id, res = first(engine.assets)
		remove_asset(engine, id)
	end

	FTFont.done()
	GRU.done(engine.renderer)
	done_window(engine)
end

should_close(engine::Engine) = engine.shouldClose || GLFW.WindowShouldClose(engine.window)

function render(engine::Engine)
	call_event(engine, :render)
	GRU.render_frame(engine.renderer)
end

deltatime(engine::Engine) = engine.timeNow - engine.timePrev

function update(engine::Engine)
	engine.timePrev = engine.timeNow
	engine.timeNow = time()
	call_event(engine, :update)
end

function input(engine::Engine)
	GLFW.PollEvents()
	call_event(engine, :input)
end

function run(engine::Engine)
	init_viewport(engine)

	while !should_close(engine)
		render(engine)
		update(engine)

		GLFW.SwapBuffers(engine.window)

		input(engine)

		yield()
	end
end

function add_event(handler::Function, engine::Engine, event::Symbol)
	handlers = get!(engine.events, event) do; Function[] end
	push!(handlers, handler)
end

function remove_event(handler::Function, engine::Engine, event::Symbol)
	handlers = engine.events[event]
	filter!(handlers) do h h==handler end
end

function call_event(engine::Engine, event::Symbol, args...)
	handlers = get!(engine.events, event) do; Function[] end
	foreach(handlers) do h h(engine, event, args...) end
end

asset_path(engine::Engine, path::String) = joinpath(engine.dataPath, path)

asset_id(filename::String, args...) = filename * reduce((v1, v2)->"$(v1)_$v2", "", args)

function add_asset(engine::Engine, id::Symbol, val)
	@assert !haskey(engine.assets, id)
	engine.assets[id] = val
end

function remove_asset(engine, id)
	delete!(engine.assets, id)
end

function set_typed(val, def::Dict{Symbol, Any}, key::Symbol, dataType::DataType)
	if !isa(val, dataType)
		if isa(val, String) && !(dataType <: AbstractString || dataType == Symbol)
			val = eval(parse(val))
		end
		val = dataType(val)
		def[key] = val
	end
	val
end

get_typed(def::Dict{Symbol, Any}, key::Symbol, dataType::DataType) = set_typed(def[key], def, key, dataType)
get_typed!(default::Function, def::Dict{Symbol, Any}, key::Symbol, dataType::DataType) = set_typed(get!(default, def, key), def, key, dataType)
get_typed!(def::Dict{Symbol, Any}, key::Symbol, defVal, dataType::DataType = typeof(defVal)) = set_typed(get!(()->defVal, def, key), def, key, dataType)

function resolve_def(engine::Engine, defpath::String, def::Dict{Symbol, Any})
	def[:defpath] = defpath
end

function get_def(engine::Engine, defname::String)
	path = map(Symbol, split(defname, '/'))
	container = engine.defs
	for i = 1:length(path)-1
		container = get!(container, path[i]) do; Dict{Symbol, Any}() end
	end
	def = get!(container, path[end]) do
		filename = joinpath(engine.dataPath, defname*".json")
		if !isfile(filename)
			return nothing
		end
		json = JSON.parsefile(filename, dicttype=Dict{Symbol, Any})
		resolve_def(engine, defname, json)
		json
	end
	def
end

load_def(engine::Engine, defname::String) = load_def(engine, get_def(engine, defname))

function load_def(engine::Engine, def::Dict{Symbol, Any})
	instance = get(def, :instance, false)
	!isa(instance, Bool) && return instance
	objType = get_typed(def, :type, DataType)
	obj = init(engine, objType, def)
	if instance == true
		def[:instance] = obj
	end
	obj
end

function init{T}(engine::Engine, ::Type{T}, def::Dict{Symbol, Any})
	obj = T()
	for i = 1:nfields(T)
		field = fieldname(T, i)
		if haskey(def, field)
			val = def[field]
			if isa(val, String)
				reference = get_def(engine, val)
				if isa(reference, Dict{Symbol, Any}) && haskey(val, :type) && get_typed(val, :type, DataType) <: fieldtype(T, i)
					val = reference
					def[field] = reference
				end
			end
			dstType = fieldtype(T, i)
			if isa(val, Dict{Symbol, Any}) && haskey(val, :type) && vget_typed(val, :type, DataType) <: dstType
				val = load_def(engine, val)
			end
			if dstType <: AbstractArray
				copy!(getfield(obj, field), val)
			else
				setfield!(obj, field, val)
			end
		end
	end
	obj
end
