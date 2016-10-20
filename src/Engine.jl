type Engine
	renderer::GRU.Renderer
	defs::Dict{Symbol, Any}
	dataPath::String
	assets::Dict{Symbol, Any}

	Engine(dataPath::String) = new(GRU.Renderer(), Dict{Symbol, Any}(), dataPath, Dict{Symbol, Any}())
end

function init(engine::Engine)
	GRU.init(renderer)
	FTFont.init()
end

function done(engine::Engine)
	while !isempty(engine.assets)
		id, res = first(engine.assets)
		remove_asset(engine, id)
	end

	FTFont.done()
	GRU.done(renderer)
end

asset_id(::Any, filename::String, args...) = filename * reduce((v1, v2)->"$(v1)_$v2", "", args)

function add_asset(engine::Engine, id::Symbol, val)
	@assert !haskey(engine.assets, id)
	engine.assets[id] = val
end

function remove_asset(engine, id)
	delete!(engine.assets, id)
end

function resolve_def(engine::Engine, defpath::String, def::Dict{Symbol, Any})
	if haskey(def, :type)
		def[:type] = eval(parse(def[:type]))::DataType
	end
	def[:defpath] = defpath
end

function get_def(engine::Engine, defname::String)
	path = split(defname, '/')
	container = engine.defs
	for i = 1:length(path)-1
		container = get!(container, path[i]) do; Dict{Symbol, Any}() end
	end
	def = get!(container, path[end]) do
		filename = joinpath(engine.datapath, defname*".json")
		if !isfile(filename)
			return nothing
		end
		json = JSON.parsefile(filename)
		resolve_def(engine, defname, json)
	end
	def
end

load_def(engine::Engine, defname::String) = load_def(engine, get_def(engine, defname))

function load_def(engine::Engine, def::Dict{Symbol, Any})
	def = get_def(engine, defname)
	instance = get(def, :instance, false)
	!isa(instance, Bool) && return instance
	objType = def[:type]
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
				if isa(reference, Dict{Symbol, Any}) && haskey(val, :type) && val[:type] <: fieldtype(T, i)
					val = reference
					def[field] = reference
				end
			end
			if isa(val, Dict{Symbol, Any}) && haskey(val, :type) && val[:type] <: fieldtype(T, i)
				setfield!(obj, field, load_def(engine, val))
			else
				setfield!(obj, field, val)
			end
		end
	end
	obj
end
