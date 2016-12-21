type Spatial <: LeafObj
	parent::NodeObj
	matLocal::Matrix{Float32}
	matWorld::Matrix{Float32}
	version::UInt
	parentVersion::UInt
	boundLocal::Shape{Float32}
	boundWorld::Shape{Float32}

	Spatial(matLocal = eye(Float32, 4), boundLocal::Shape{Float32} = Empty{Float32}()) =
		new(NoNode(), matLocal, eye(Float32, 4), 1, 0, boundLocal, similar(boundLocal))
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
get_local_bound(spatial::Spatial) = spatial.boundLocal

function calc_parent_bound(parent::NodeObj, spatial::Spatial)
	set_local_bound(spatial, calc_local_bound(parent))
end

function child_added(parent::NodeObj, spatial::Spatial)
	invoke(child_added, (typeof(parent), LeafObj), parent, spatial)
	add_event(parent, :child_added, spatial) do owner, event, child
		calc_parent_bound(owner, spatial)
	end
	set_local_bound(spatial, calc_local_bound(parent))
end

function child_removed(parent::NodeObj, spatial::Spatial)
	remove_event(spatial, parent, :child_added)
	invoke(child_removed, (typeof(parent), LeafObj), parent, spatial)
end

function update_bound(spatial::Spatial)
	transform(spatial.boundWorld, spatial.matWorld, spatial.boundLocal)
	call_event(spatial.parent, :bound_updated, spatial)
end

function update_transform(spatial::Spatial)
	parentVer, parentWorld = get_world_transform(spatial.parent.parent)
	if parentVer > spatial.parentVersion
		A_mul_B!(spatial.matWorld, parentWorld, spatial.matLocal)
		spatial.version += 1
		spatial.parentVersion = parentVer
		update_bound(spatial)
	end
end

function get_world_transform(node::NodeObj)
	!haskey(node.children, :spatial) && return 1, eye(Float32, 4)
	get_world_transform(node.children[:spatial])
end

function get_world_transform(spatial::Spatial)
	update_transform(spatial)
	spatial.version, spatial.matWorld
end

function set_local_transform(spatial::Spatial, m::Matrix{Float32})
	spatial.matLocal[:] = m
	spatial.version += 1
	spatial.parentVersion = 0
	nothing
end

function set_local_bound(spatial::Spatial, bound::Shape{Float32})
	#info("set_local_bound spatial")
	spatial.boundLocal = bound
	if typeof(spatial.boundWorld) != typeof(spatial.boundLocal)
		spatial.boundWorld = similar(spatial.boundLocal)
	end
	spatial.version += 1
	spatial.parentVersion = 0
	nothing
end

function get_world_bound(spatial::Spatial)
	update_transform(spatial)
	spatial.boundWorld
end


type Visual <: LeafObj
	id::Symbol
	parent::NodeObj
	visual::GRU.Renderable
	matLocal::Matrix{Float32}
	parentVersion::UInt

	Visual(id::Symbol, visual::GRU.Renderable, matLocal::Matrix{Float32} = eye(Float32, 4)) = new(id, NoNode(), visual, matLocal, 0)
end

function init(engine::Engine, ::Type{Visual}, def::Dict{Symbol, Any})::Visual
	id = get_id!(def)
	visual = load_def(engine, def[:visual])
	matLocal = get_transform(def)
	vis = Visual(id, visual, matLocal)
	vis
end

get_id(v::Visual) = v.id
function get_local_bound(v::Visual)
	bound = transform(v.matLocal, GRU.localbound(v.visual))
	#info("get_local_bound $bound")
	bound
end

function update(v::Visual)
	parentVer, parentWorld = get_world_transform(v.parent)
	if parentVer > v.parentVersion
		GRU.settransform(v.visual, parentWorld * v.matLocal)
		v.parentVersion = parentVer
	end
end

function render(v::Visual, engine::Engine)
	update(v)
	GRU.add(engine.renderer, v.visual)
end
