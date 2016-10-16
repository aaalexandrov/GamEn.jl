type Engine
	renderer::GRU.Renderer
	defs::Dict{String, Any}
	dataPath::String
	resources::Dict{Symbol, Any}
	resourceTypes::Dict{String, DataType}

	Engine(dataPath::String) = new(GRU.Renderer(), Dict{String, Any}(), dataPath)
end

function init(engine::Engine)
	GRU.init(renderer)
	FTFont.init()

	register_resource_type(engine, ".sh", GRU.Shader)
	register_resource_type(engine, ".png", GRU.Texture)
	register_resource_type(engine, ".ttf", FTFont.Font)
end

function done(engine::Engine)
	while !isempty(engine.resources)
		id, res = first(engine.resources)
		unload_resource(engine, id)
	end

	FTFont.done()
	GRU.done(renderer)
end

function register_resource_type(engine::Engine, fileExt::String, dataType::DataType)
	@assert !haskey(engine.resourceTypes, fileExt)
	engine.resourceTypes[fileExt] = dataType
end

unregister_resource_type(engine::Engine, fileExt::String) = delete!(engine.resourceTypes, fileExt)

function load_resource(engine::Engine, filename::String, args...)
	ext = splitext(filename)[2]
	dataType = engine.resourceTypes[ext]
	id = resource_id(dataType, filename, args...)
	get!(engine.resources, id) do
		fullPath = joinpath(dataPath, filename)
		resource_load(engine, dataType, fullPath, args...)
	end
end

function unload_resource(engine::Engine, id::Symbol)
	resource = engine.resources[id]
	delete!(engine.resources, id)
	resource_unload(engine, resource)
end

resource_id(::Any, filename::String, args...) = filename * reduce((v1, v2)->"$(v1)_$v2", "", args)

function resource_load(engine::Engine. ::Type{GRU.Shader}, filename::String)
	shader = GRU.Shader()
	GRU.init(shader, engine.Renderer, filename)
	shader
end

function resource_load(engine::Engine, ::Type{GRU.Texture}, filename::String)
	texture = GRU.Texture()
	GRU.init(texture, engine.Renderer, filename)
	texture
end

function resource_load(engine::Engine, ::Type{FTFont.Font}, filename::String, sizeXY::Tuple{Real, Real} = (32, 32), chars = '\u0000':'\u00ff', faceIndex::Real = 0)
	FTFont.load(filename, sizeXY = sizeXY, faceIndex = faceIndex, chars = chars)
end

resource_unload(engine::Engine, gruResource::GRU.Resource) = GRU.done(gruResource)
resource_unload(engine::Engine, ::Any) = nothing

function load_def(engine::Engine, defname::String)
	path = split(defname, '/')
	container = engine.defs
	for i = 1:length(path)-1
		container = get!(container, path[i]) do; Dict{String, Any}() end
	end
	def = get!(container, path[end]) do
		JSON.parsefile(joinpath(engine.datapath, defname*".json"))
	end
	objType = eval(parse(def["type"]))
	obj = objType()
	init(obj, def)
	obj
end
