mutable struct Engine
	renderer::GRU.Renderer
	defs::Dict{Symbol, Any}
	dataPath::String
	assets::Dict{Symbol, Any}
	events::EventHandlers
	shouldClose::Bool
	timePrev::Float64
	timeNow::Float64
	window::GLFW.Window

	function Engine(dataPath::String)
		now = time()
		new(GRU.Renderer(), Dict{Symbol, Any}(), dataPath, Dict{Symbol, Any}(), Dict{Symbol, Vector{Function}}(), false, now, now)
	end
end

init(engine::Engine, defname::String) = init(engine, json_load(asset_path(engine, defname*".json")))

function init(engine::Engine, def::Dict{Symbol, Any} = Dict{Symbol, Any}())
	init_window(engine, def)
	GRU.init(engine.renderer)
	init(engine.renderer, def)
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

asset_path(engine::Engine, path::String) = joinpath(engine.dataPath, path)

asset_id(filename::String, args...) = filename * reduce((v1, v2)->"$(v1)_$v2", args; init = "")
id_count = let count = 0
	()->count += 1
end
next_id(prefix::String) = asset_id(prefix, id_count())

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
			val = eval(Meta.parse(val))
		end
		if !isa(val, dataType)
			val = dataType(val)
		end
		def[Symbol(string(key)*"#org")] = def[key] # remember the original value in case we need to resave the json
		def[key] = val
	end
	val
end

get_typed(def::Dict{Symbol, Any}, key::Symbol, dataType::DataType) = set_typed(def[key], def, key, dataType)
get_typed!(default::Function, def::Dict{Symbol, Any}, key::Symbol, dataType::DataType) = set_typed(get!(default, def, key), def, key, dataType)
get_typed!(def::Dict{Symbol, Any}, key::Symbol, defVal, dataType::DataType = typeof(defVal)) = set_typed(get!(()->defVal, def, key), def, key, dataType)

function get_transform(def::Dict{Symbol, Any})
	mat = Matrix{Float32}(I, 4, 4)
	if haskey(def, :transform)
		mat[:] = get_typed(def, :transform, Vector{Float32})
	else
		if haskey(def, :scale)
			mat = Math3D.scale(get_typed(def, :scale, Vector{Float32}))
		end
		if haskey(def, :rot_axis_angle)
			axis_angle = get_typed(def, :rot_axis_angle, Vector{Float32})
			mat = Math3D.rot(axis_angle[1:3], axis_angle[4]) * mat
		end
		if haskey(def, :position)
			mat = Math3D.trans(get_typed(def, :position, Vector{Float32})) * mat
		end
	end
	mat
end

get_id!(def::Dict{Symbol, Any}, prefix::String = string(def[:type])) = get_typed!(def, :id, Symbol) do; next_id(prefix) end

function resolve_def(engine::Engine, defpath::String, def::Dict{Symbol, Any})
	def[:defpath] = defpath
end

function merge_rec!(dst::AbstractDict, src::AbstractDict)
	for (k, v) in src
		if !haskey(dst, k)
			dst[k] = v
		elseif isa(dst[k], Associative) && isa(v, Associative)
			merge_rec!(dst[k], v)
		else
			@assert dst[k] == v
		end
	end
end

function def_container(engine::Engine, path::Vector{Symbol})
	container = engine.defs
	for i = 1:length(path)
		container = get!(container, path[i]) do; Dict{Symbol, Any}() end
	end
	container
end

function try_load(engine::Engine, path::Vector{Symbol})
	defname = join(map(string, path), '/')
	filename = asset_path(engine, defname*".json")
	if !isfile(filename)
		return nothing
	end
	json = json_load(filename)
	resolve_def(engine, defname, json)
	container = def_container(engine, path)
	merge_rec!(container, json)
	container
end

json_load(path::String) = JSON.parsefile(path, dicttype=Dict{Symbol, Any})

function get_def(engine::Engine, defname::String)
	path = map(Symbol, split(defname, '/'))
	container = def_container(engine, path[1:end-1])
	if haskey(container, path[end])
		return container[path[end]]
	end
	# if the def is not present, we start trying to load defs from prefixes of its path, and check if a loaded prefix contains the required key
	for i = length(path):-1:1
		loaded = try_load(engine, path[1:i])
		if loaded != nothing # a def was loaded, now we check if the required key was merged by this def into the container
			if haskey(container, path[end])
				return container[path[end]]
			end
		end
	end
	nothing
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

function original_def(def::Dict{Symbol, Any})
	dst = Dict{Symbol, Any}()
	for (k,v) in def
		val = v
		if k == :instance
			val = isa(val, Bool) ? v : true
		elseif k == :defpath || endswith(string(k), "#org")
			continue
		else
			orgKey = Symbol(string(k)*"#org")
			if haskey(def, orgKey)
				val = def[orgKey]
			end
		end
		if isa(val, Dict{Symbol, Any})
			val = original_def(val)
		end
		dst[k] = val
	end
	dst
end

function save_def(engine::Engine, def::Dict{Symbol, Any}, target::String = def[:defpath])
	write(asset_path(engine, target*".json"), JSON.json(original_def(def), 2))
end

function init(engine::Engine, ::Type{T}, def::Dict{Symbol, Any}) where T
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
