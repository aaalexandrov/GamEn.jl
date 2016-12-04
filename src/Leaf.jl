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

get_id(t::Spatial) = :spatial

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
	spatial.boundLocal = bound
	update_bound(spatial)
	nothing
end

funciton get_world_bound(spatial::Spatial)
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

get_id(v::Visual) = v.id

function update(v::Visual)
	parentVer, parentWorld = get_world(get(parent))
	if parentVer > v.parentVersion
		GRU.settransform(visual.visual, parentWorld * v.matLocal)
		v.parentVersion = parentVer
	end
end
