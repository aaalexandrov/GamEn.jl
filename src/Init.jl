function init(engine::Engine, def::Dict{Symbol, Any})
end

function init(engine::Engine, ::Type{GRU.Renderer}, def::Dict{Symbol, Any})
end

function init(engine::Engine, ::Type{GRU.Shader}, def::Dict{Symbol, Any})::GRU.Shader
	path = def[:shader]
	assetPath = asset_path(engine, path)
	id = Symbol(assetPath)
	if GRU.has_resource(engine.renderer, id)
		return GRU.get_resource(engine.renderer, id)
	end
	setupFn = get_typed!(def, :setupfn, identity, Function)
	GRU.init(GRU.Shader(), engine.renderer, assetPath, setupFn)
end

function init(engine::Engine, ::Type{GRU.Texture}, def::Dict{Symbol, Any})::GRU.Texture
	path = def[:image]
	assetPath = asset_path(engine, path)
	id = Symbol(assetPath)
	if GRU.has_resource(engine.renderer, id)
		return GRU.get_resource(engine.renderer, id)
	end
	GRU.init(GRU.Texture(), engine.renderer, assetPath)
end

function init(engine::Engine, ::Type{GRU.Mesh}, def::Dict{Symbol, Any})::GRU.Mesh
	local model, id
	if haskey(def, :obj)
		path = def[:obj]
		assetPath = asset_path(engine, path)
		id = Symbol(assetPath)
		if GRU.has_resource(engine.renderer, id)
			return GRU.get_resource(engine.renderer, id)
		end
		model = ObjGeom.load_obj(assetPath)
	else
		shape = def[:shape]
		sides = get(def, :sides, 4)
		smooth = get_typed!(def, :smoothing, ObjGeom.SmoothNone)
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
		direction = get_typed(def, :project_texcoord, Vector{Float32})
		ObjGeom.add_texcoord(model, direction)
	end
	shader = load_def(engine, def[:shader])
	streams, indices = ObjGeom.get_indexed(model)
	GRU.init(GRU.Mesh(), shader, streams, map(UInt16, indices), positionFunc = GRU.position_func(:position), id = id)
end

function uniform_type(t::DataType)
	if GRU.isvector(t) || GRU.ismatrix(t)
		return Vector{eltype(t)}
	end
	if t <: GRU.SamplerType
		return GRU.Texture
	end
	t
end

function init_material(engine::Engine, material::GRU.Material, def::Dict{Symbol, Any})
	if haskey(def, :uniforms)
		uniforms = def[:uniforms]
		for (u, v) in uniforms
			if isa(v, String) || isa(v, Dict)
				v = load_def(engine, v)
				uniforms[u] = v
			end
			varType = uniform_type(material.shader.uniforms[u].varType)
			GRU.setuniform(material, u, varType(v))
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
		GRU.settransform(model, get_typed(def, :transform, Vector{Float32}))
	else
		mat = eye(Float32, 4)
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
		GRU.settransform(model, mat)
	end
	model
end

function init(engine::Engine, ::Type{GRU.Font}, def::Dict{Symbol, Any})::GRU.Font
	facename = def[:facename]
	sizeXY = get(def, :sizexy, (32, 32))
	faceIndex = get(def, :faceindex, 0)
	chars = get(def, :chars, '\u0000':'\u00ff')
	ftFont = FTFont.loadfont(asset_path(engine, facename), sizeXY = (sizeXY...), faceIndex = faceIndex, chars = chars)

	shader = load_def(engine, def[:shader])
	positionFunc = get_typed!(def, :positionfn, GRU.position_func(:position))
	textureUniform = get_typed!(def, :texture_uniform, :diffuseTexture)
	maxCharacters = get(def, :maxchars, 2048)
	font = GRU.init(GRU.Font(), ftFont, shader, positionFunc = positionFunc, textureUniform = textureUniform, maxCharacters = maxCharacters)
	init_material(engine, font.model.material, def)
	font
end
