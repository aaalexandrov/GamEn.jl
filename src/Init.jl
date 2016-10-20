function init(engine::Engine, def::Dict{Symbol, Any})
end

function init(engine::Engine, ::Type{GRU.Renderer}, def::Dict{Symbol, Any})
end

function init(engine::Engine, ::Type{GRU.Shader}, def::Dict{Symbol, Any})::GRU.Shader
	path = def[:shader]
	id = Symbol(path)
	if GRU.has_resource(engine.renderer, id)
		return GRU.get_resource(engine.renderer, id)
	end
	setupFn = get(def, :setupfn, identity)
	if !isa(setupFn, Function)
		setupFn = eval(parse(setupFn))::Function
		def[:setupfn] = setupFn
	end
	GRU.init(GRU.Shader(), engine.renderer, path, setupMaterial = setupFn)
end

function init(engine::Engine, ::Type{GRU.Texture}, def::Dict{Symbol, Any})::GRU.Texture
	path = def[:image]
	id = Symbol(path)
	if GRU.has_resource(engine.renderer, id)
		return GRU.get_resource(engine.renderer, id)
	end
	GRU.init(GRU.Texture(), engine.renderer, path)
end

function init(engine::Engine, ::Type{GRU.Mesh}, def::Dict{Symbol, Any})::GRU.Mesh
	local model, id
	if haskey(def, :obj)
		path = def[:obj]
		id = Symbol(path)
		if GRU.has_resource(engine.renderer, id)
			return GRU.get_resource(engine.renderer, id)
		end
		model = ObjGeom.load_obj(path)
	else
		shape = def[:shape]
		sides = get(def, :sides, 4)
		smooth = get(def, :smoothing, ObjGeom.SmoothNone)
		if !isa(smooth, ObjGeom.SMOOTHING)
			smooth = eval(parse(smooth))::ObjGeom.SMOOTHING
			def[:smoothing] = smooth
		end
		id = Symbol(asset_id(shape, sides, Int(smooth)))
		if GRU.has_resource(engine.renderer, id)
			return GRU.get_resource(engine.renderer, id)
		end
		model = shape == "prism"? ObjGeom.prism(sides; smooth = smooth): (shape == "pyramid"? ObjGeom.pyramid(sides; smooth = smooth): ObjGeom.sphere(sides; smooth = smooth))
	end
	streams, indices = ObjGeom.get_indexed(model)
	GRU.init(GRU.Mesh(), engine.renderer, streams, map(UInt16, indices), positionFunc = GRU.position_func(:position), id = id)
end

function init(engine::Engine, ::Type{GRU.Material}, def::Dict{Symbol, Any})::GRU.Material
	shader = load_def(engine, def[:shader])
	material = GRU.Material(shader)
	if haskey(def, :uniforms)
		for (u, v) in def[:uniforms]
			GRU.setuniform(material, Symbol(u), v)
		end
	end
	material
end

function init(engine::Engine, ::Type{GRU.Model}, def::Dict{Symbol, Any})::GRU.Model
	mesh = load_def(engine, def[:mesh])
	material = load_def(engine, def[:material])
	GRU.Model(mesh, material)
end

function init(engine::Engine, ::Type{GRU.Font}, def::Dict{Symbol, Any})::GRU.Font
	facename = def[:facename]
	sizeXY = get(def, :sizexy, (32, 32))
	faceIndex = get(def, :faceindex, 0)
	chars = get(def, :chars, chars = '\u0000':'\u00ff')
	ftFont = FTFont.loadfont(facename, sizeXY = sizeXY, faceIndex = faceIndex, chars = chars)

	shader = load_def(engine, def[:shader])
	positionFunc = get(def, :positionfn, GRU.position_func(:position))
	if !isa(positionFunc, Function)
		positionFunc = eval(parse(positionFunc))::Function
		def[:positionfn] = positionFunc
	end
	textureUniform = Symbol(get(def, :texture_uniform, :diffuseTexture))
	maxCharacters = get(def, :maxchars, 2048)
	GRU.init(GRU.Font(), ftFont, shader, positionFunc = positionFunc, textureUniform = textureUniform, maxCharacters = maxCharacters)
end
