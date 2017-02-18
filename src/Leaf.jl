type Data3D
	mat::Matrix{Float32}
	bound::Shape{Float32}

	Data3D(bound = empty!(AABB()), mat = eye(Float32, 4)) = new(mat, bound)
end

function assure_bound_type(data::Data3D, bound::Shape)
	if typeof(data.bound) != typeof(bound)
		data.bound = similar(bound)
	end
	nothing
end

type Spatial <: LeafObj
	parent::NodeObj
	local3D::Data3D
	world3D::Data3D
	next3D::Data3D

	Spatial(matLocal, boundLocal) = new(NoNode(), Data3D(boundLocal, matLocal), Data3D(similar(boundLocal)), Data3D(similar(boundLocal)))
end

function init(engine::Engine, ::Type{Spatial}, def::Dict{Symbol, Any})::Spatial
	matLocal = get_transform(def)
	boundLocal = Empty{Float32}()
	if haskey(def, :boundLocal)
		boundLocal = load_def(engine, def[:boundLocal])
	end
	statial = Spatial(matLocal, boundLocal)
end

get_id(t::Spatial) = :spatial

get_local_transform(spatial::Spatial) = spatial.local3D.mat
function set_local_transform(spatial::Spatial, m::Matrix{Float32})
	spatial.next3D[:] = m
	world = top(spatial)
	!isa(world, BaseWorld) && return
	register_transform_update(world, spatial.parent)
	nothing
end

get_local_bound(spatial::Spatial) = spatial.local3D.bound
function set_local_bound(spatial::Spatial, bound::Shape{Float32})
	spatial.next3D.bound = bound
	world = top(spatial)
	!isa(world, BaseWorld) && return
	register_bound_update(world, spatial.parent)
	nothing
end

get_world_transform(spatial::Spatial) = spatial.world3D.mat
get_world_bound(spatial::Spatial) = spatial.world3D.bound

function next_transform(spatial::Spatial)
	spatial.local3D.mat[:] = spatial.next3D.mat
end

function next_bound(spatial::Spatial)
	assure_bound_type(spatial.local3D, spatial.next3D.bound)
	assign(spatial.local3D.bound, spatial.next3D.bound)
end

function update_world_transform(spatial::Spatial, worldMat::Matrix{Float32})
	A_mul_B!(spatial.world3D.mat, worldMat, spatial.local3D.mat)
end

function update_world_bound(spatial::Spatial)
	assure_bound_type(spatial.world3D, spatial.local3D.bound)
	transform(spatial.world3D.bound, spatial.world3D.mat, spatial.local3D.bound)
end


type Visual <: LeafObj
	id::Symbol
	parent::NodeObj
	visual::GRU.Renderable
	matLocal::Matrix{Float32}

	Visual(id::Symbol, visual::GRU.Renderable, matLocal::Matrix{Float32} = eye(Float32, 4)) = new(id, NoNode(), visual, matLocal)
end

function init(engine::Engine, ::Type{Visual}, def::Dict{Symbol, Any})::Visual
	id = get_id!(def)
	visual = load_def(engine, def[:visual])
	matLocal = get_transform(def)
	vis = Visual(id, visual, matLocal)
	vis
end

get_id(v::Visual) = v.id
get_local_bound(v::Visual) = transform(v.matLocal, GRU.localbound(v.visual))

function update(v::Visual)
	parentWorld = get_world_transform(v.parent)
	GRU.settransform(v.visual, parentWorld * v.matLocal)
end

function render(v::Visual, engine::Engine)
	update(v)
	GRU.add(engine.renderer, v.visual)
end
