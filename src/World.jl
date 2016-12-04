type NodeInfo
	boundHandler::Function
	addHandler::Function
	removeHandler::Function
	bound::AABB{Float32}
end

type World <: NodeObj
	parent::NodeObj
	children::Dict{Symbol, BaseObj}
	octree::Octree.Tree{NodeObj, Float32}
	nodes::Dict{NodeObj, NodeInfo}
	id::Symbol
	engine::Engine
	renderHandler::Function

	World() = new(NoNode(), Dict{Symbol, BaseObj}(), Octree.Tree{NodeObj, Float32}(), Dict{NodeObj, NodeInfo}())
end

function init(world::World, engine::Engine, id::Symbol = :world)
	world.id = id
	world.engine = engine
	world.renderHandler = add_event(engine, :render) do owner, event
		render(world)
	end
end

function done(world::World)
	remove_event(world.renderHandler, engine, :render)
end

function render(world::World)
	frustum = getfrustum(world.engine.renderer.camera)
	
end

function add_node(world::World, node::NodeObj)
	nodeInfo = world.nodes[node]
	nodeInfo.bound = getbound(node)
	Octree.add(world.octree, node, bound)
end

function remove_node(world::World, node::NodeObj)
	bound = world.nodes[node].bound
	Octree.remove(world.octree, node, bound)
end

function bound_updated(world::World, node::NodeObj)
	remove_node(world, node)
	add_node(world, node)
end


function process_spatial(f::Function, world::World, obj::BaseObj)
	if isa(obj, Spatial)
		f(obj.parent)
	else
		for_children(f, obj)
	end
end

function child_added(world::World, obj::BaseObj)
	process_spatial(obj) do c
		if has_transform(c)
			@assert !haskey(world.nodes, c)
			nodeInfo = NodeInfo()
			nodeInfo.boundHandler = add_event(node, :bound_updated) do owner, event, spatial
				bound_updated(world, owner)
			end
			nodeInfo.addHandler = add_event(node, :child_added) do owner, event, child
				child_added(world, child)
			end
			nodeInfo.removeHandler = add_event(node, :child_removed) do owner, event, child
				child_removed(world, child)
			end
			world.nodes[c] = nodeInfo
			add_node(world, c)
		end
	end
end

function child_removed(world::World, obj::BaseObj)
	process_spatial(obj) do c
		if has_transform(c)
			remove_node(world, c)
			nodeInfo = world.nodes[c]
			remove_event(nodeInfo.boundHandler, c, :bound_updated)
			remove_event(nodeInfo.addHandler, c, :child_added)
			remove_event(nodeInfo.removeHandler, c, :child_removed)
			delete!(world.nodes, c)
		end
	end
end
