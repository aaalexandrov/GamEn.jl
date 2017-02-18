type UpdateInfo
	transform::Bool
	bound::Bool
end

type World <: BaseWorld
	parent::NodeObj
	children::Dict{Symbol, BaseObj}
	octree::Octree.Tree{NodeObj, Float32}
	updates::Dict{NodeObj, UpdateInfo}
	id::Symbol
	engine::Engine

	World(engine::Engine, aabb::AABB{Float32}, id::Symbol = :world) = new(NoNode(), Dict{Symbol, BaseObj}(), Octree.Tree(NodeObj, aabb), Dict{NodeObj, UpdateInfo}(), id, engine)
end

function init(world::World)
	add_event(world.engine, :render, world) do owner, event
		render(world)
	end
	add_event(world.engine, :update, world) do owner, event
		update_registered(world)
	end
	world
end

function init(engine::Engine, ::Type{World}, def::Dict{Symbol, Any})::World
	id = get_id!(def)
	bound = haskey(def, :bound)? load_def(engine, def[:bound]) : AABB{Float32}([-256f0 256f0; -256f0 256f0; -256f0 256f0])
	world = init(World(engine, bound, id))
	init_children(engine, world, def)
	world
end

function done(world::World)
	remove_event(world, engine, :render)
end

function render_node(world::World, frustum::Convex{Float32}, node::Octree.Node{NodeObj}, nodeBound::AABB{Float32})
	outside(frustum, nodeBound) && return
	for obj in node.objects
		render(obj, world.engine)
	end
	for z = 1:2, y = 1:2, x = 1:2
		if node.subNodes[x, y, z] != Octree.NullNode{NodeObj}()
			subBound = getsubbound(nodeBound, [x, y, z])
			render_node(world, frustum, node.subNodes[x, y, z], subBound)
		end
	end
	nothing
end

function render(world::World)
	frustum = GRU.getfrustum(world.engine.renderer.camera)
	render_node(world, frustum, world.octree.root, world.octree.bound)
end

add_to_world(world::World, base::BaseObj) = nothing
function add_to_world(world::World, node::NodeObj)
	!haskey(node.children, :spatial) && return
	spatial = node.children[:spatial]
	worldMat = get_world_transform(node.parent)
	update_world_transform(spatial, worldMat)
	update_world_bound(spatial)
	add_node(world, node)
end

remove_from_world(world::World, base::BaseObj) = nothing
function remove_from_world(world::World, node::NodeObj)
	remove_node(world, node)
end

function add_node(world::World, node::NodeObj)
	bound = getbound(node)
	if !isempty(bound)
		Octree.add(world.octree, node, bound)
	end
end

function remove_node(world::World, node::NodeObj)
	bound = getbound(node)
	if !isempty(bound)
		Octree.remove(world.octree, node, bound)
	end
end

function register_transform_update(world::World, node::NodeObj)
	upd = get!(world.updates, node) do; UpdateInfo(false, false) end
	upd.transform = true
end

function register_bound_update(world::World, node::NodeObj)
	upd = get!(world.updates, node) do; UpdateInfo(false, false) end
	upd.bound = true
end

const defUpd = UpdateInfo(false, false)

update_transform(world::BaseWorld, leaf::BaseObj, worldMat::Matrix{Float32}) = nothing
function update_transform(world::World, node::NodeObj, worldMat::Matrix{Float32})
	!haskey(node.children, :spatial) && return
	remove_node(world, node)
	spatial = node.children[:spatial]
	upd = get(world.updates, node, defUpd)
	if upd.transform
		next_transform(spatial)
	end
	update_world_transform(spatial, worldMat)
	for child in node.children
		update_transform(world, child, get_world_transform(spatial))
	end
	if upd.bound
		next_bound(spatial)
		upd.bound = false
	end
	update_world_bound(spatial)
	add_node(world, node)
end

function update_registered(world::World)
	updateRoots = Set{NodeObj}()
	for (node, upd) in world.updates
		!upd.transform && continue
		root = node
		while true
			node = node.parent
			node == world && break
			if haskey(node.children, :spatial) && get(world.updates, node, defUpd).transform
				root = node
			end
		end
		push!(updateRoots, root)
	end
	for node in updateRoots
		update_transform(world, node, get_world_transform(node.parent))
	end
	for (node, upd) in world.updates
		!upd.bound && continue
		remove_node(world, node)
		spatial = node.children[:spatial]
		next_bound(spatial)
		update_world_bound(spatial)
		add_node(world, node)
	end
	empty!(world.updates)
end
