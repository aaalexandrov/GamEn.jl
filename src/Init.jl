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
	GRU.init(GRU.Shader(), engine.renderer, asset_path(engine, path), setupMaterial = setupFn)
end

function init(engine::Engine, ::Type{GRU.Texture}, def::Dict{Symbol, Any})::GRU.Texture
	path = def[:image]
	id = Symbol(path)
	if GRU.has_resource(engine.renderer, id)
		return GRU.get_resource(engine.renderer, id)
	end
	GRU.init(GRU.Texture(), engine.renderer, asset_path(engine, path))
end

function init(engine::Engine, ::Type{GRU.Mesh}, def::Dict{Symbol, Any})::GRU.Mesh
	local model, id
	if haskey(def, :obj)
		path = def[:obj]
		id = Symbol(path)
		if GRU.has_resource(engine.renderer, id)
			return GRU.get_resource(engine.renderer, id)
		end
		model = ObjGeom.load_obj(asset_path(engine, path))
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
		model =
			if shape == "prism"
				ObjGeom.prism(sides; smooth = smooth)
			elseif shape == "pyramid"
				ObjGeom.pyramid(sides; smooth = smooth)
			elseif shape == "sphere"
				ObjGeom.sphere(sides; smooth = smooth)
			elseif shape == "regularpoly"
				ObjGeom.regularpoly(sides)
			end
	end
	if haskey(def, :project_texcoord)
		direction = def[:project_texcoord]
		ObjGeom.add_texcoord(model, direction)
	end
	streams, indices = ObjGeom.get_indexed(model)
	GRU.init(GRU.Mesh(), engine.renderer, streams, map(UInt16, indices), positionFunc = GRU.position_func(:position), id = id)
end

function init_material(engine::Engine, material::GRU.Material, def::Dict{Symbol, Any})
	if haskey(def, :uniforms)
		uniforms = def[:uniforms]
		for (u, v) in uniforms
			if isa(v, String) || isa(v, Dict)
				v = load_def(engine, v)
				uniforms[u] = v
			end
			GRU.setuniform(material, u, v)
		end
	end
	if haskey(def, :states)
		states = def[:states]
		for i = 1:length(states)
			if !isa(states[i], GRU.RenderState)
				states[i] = eval(parse(states[i]))::GRU.RenderState
			end
			GRU.setstate(material, states[i])
		end
	end
	material
end

function init(engine::Engine, ::Type{GRU.Material}, def::Dict{Symbol, Any})::GRU.Material
	shader = load_def(engine, def[:shader])
	init_material(engine, GRU.Material(shader), def)
end

function init(engine::Engine, ::Type{GRU.Model}, def::Dict{Symbol, Any})::GRU.Model
	mesh = load_def(engine, def[:mesh])
	material = load_def(engine, def[:material])
	model = GRU.Model(mesh, material)
	if haskey(def, :transform)
		GRU.settransform(model, def[:transform])
	else
		mat = eye(Float32, 4)
		if haskey(def, :scale)
			mat = Math3D.scale(def[:scale])
		end
		if haskey(def, :rot_axis_angle)
			axis = def[:rot_axis_angle][1:3]
			angle = def[:rot_axis_angle][4]
			mat = Math3D.rot(axis, angle) * mat
		end
		if haskey(def, :position)
			mat = Math3D.trans(def[:position]) * mat
		end
		GRU.settransform(model, mat)
	end
	model
end

function init(engine::Engine, ::Type{GRU.Font}, def::Dict{Symbol, Any})::GRU.Font
	facename = def[:facename]
	sizeXY = get(def, :sizexy, (32, 32))
	faceIndex = get(def, :faceindex, 0)
	chars = get(def, :chars, chars = '\u0000':'\u00ff')
	ftFont = FTFont.loadfont(asset_path(engine, facename), sizeXY = sizeXY, faceIndex = faceIndex, chars = chars)

	shader = load_def(engine, def[:shader])
	positionFunc = get(def, :positionfn, GRU.position_func(:position))
	if !isa(positionFunc, Function)
		positionFunc = eval(parse(positionFunc))::Function
		def[:positionfn] = positionFunc
	end
	textureUniform = Symbol(get(def, :texture_uniform, :diffuseTexture))
	maxCharacters = get(def, :maxchars, 2048)
	font = GRU.init(GRU.Font(), ftFont, shader, positionFunc = positionFunc, textureUniform = textureUniform, maxCharacters = maxCharacters)
	init_material(engine, font.model.material, def)
	font
end
