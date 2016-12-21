type NodeInfo
	bound::AABB{Float32}
	NodeInfo() = new()
end

type World <: NodeObj
	parent::NodeObj
	children::Dict{Symbol, BaseObj}
	octree::Octree.Tree{NodeObj, Float32}
	nodes::Dict{NodeObj, NodeInfo}
	id::Symbol
	engine::Engine

	World(engine::Engine, aabb::AABB{Float32}, id::Symbol = :world) = new(NoNode(), Dict{Symbol, BaseObj}(), Octree.Tree(NodeObj, aabb), Dict{NodeObj, NodeInfo}(), id, engine)
end

function init(world::World)
	add_event(world.engine, :render, world) do owner, event
		render(world)
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
	#info("render_node $(nodeBound) $(length(node.objects))")
	outside(frustum, nodeBound) && return
	#info("render_node rendering")
	for obj in node.objects
		#info("render_node $(get_id(obj)) rendering")
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

function add_node(world::World, node::NodeObj)
	#info("add_node $(get_id(node))")
	nodeInfo = world.nodes[node]
	nodeInfo.bound = getbound(node)
	if !isempty(nodeInfo.bound)
		#info("Octree.add $(nodeInfo.bound)")
		Octree.add(world.octree, node, nodeInfo.bound)
		#info("Octree.add $(nodeInfo.bound) done")
	end
	#info("add_node $(get_id(node)) done")
end

function remove_node(world::World, node::NodeObj)
	#info("remove_node $(get_id(node))")
	bound = world.nodes[node].bound
	if !isempty(bound)
		Octree.remove(world.octree, node, bound)
	end
end

function bound_updated(world::World, node::NodeObj)
	remove_node(world, node)
	add_node(world, node)
end


function process_spatial(f::Function, obj::BaseObj)
	if isa(obj, Spatial)
		f(obj.parent)
	else
		for_children(f, obj, false)
	end
end

function child_added(world::World, obj::BaseObj)
	#info("child_added to world $(get_id(obj))")
	process_spatial(obj) do c
		#info("processing $(get_id(c))")
		world_added(c, world)
		if has_transform(c)
			@assert !haskey(world.nodes, c)
			nodeInfo = NodeInfo()
			world.nodes[c] = nodeInfo
			add_node(world, c)
			add_event(c, :bound_updated, world) do owner, event, spatial
				#info("bound_updated enter")
				bound_updated(world, owner)
				#info("bound_updated exit")
			end
			add_event(c, :child_added, world) do owner, event, child
				child_added(world, child)
			end
			add_event(c, :child_removed, world) do owner, event, child
				child_removed(world, child)
			end
		end
		#info("processing $(get_id(c)) done")
	end
	#info("child_added to world $(get_id(obj)) done")
end

function child_removed(world::World, obj::BaseObj)
	process_spatial(obj) do c
		world_removed(c, world)
		if has_transform(c)
			remove_events(world, c)
			remove_node(world, c)
			delete!(world.nodes, c)
		end
	end
end

world_added(obj::BaseObj, world::World) = nothing
world_removed(obj::BaseObj, world::World) = nothing

function world_added(spatial::Spatial, world::World)
	add_event(world.engine, :update, spatial) do engine, event
		get_world_transform(spatial)
		#info(spatial.boundWorld)
	end
end

function world_removed(spatial::Spatial, world::World)
	remove_event(world.engine, :update, spatial)
end
