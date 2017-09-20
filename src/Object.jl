abstract type BaseObj end

abstract type LeafObj <: BaseObj end

abstract type NodeObj <: BaseObj end

abstract type BaseWorld <: NodeObj end

type NoNode <: NodeObj
end

get_id(obj::BaseObj) = obj.id

function set_parent(child::BaseObj, parent::NodeObj = NoNode())
	if child.parent != NoNode()
		removing_child(parent, child)
		@assert child.parent.children[get_id(child)] == child
		delete!(child.parent.children, get_id(child))
	end
	child.parent = parent
	if parent != NoNode()
		@assert !haskey(parent.children, get_id(child))
		parent.children[get_id(child)] = child
		added_child(parent, child)
	end
end

added_child(parent::NodeObj, child::BaseObj) = nothing
removing_child(parent::NodeObj, child::BaseObj) = nothing

function top(obj::BaseObj)
	t = obj
	while t.parent != NoNode()
		t = t.parent
	end
	t
end

function init_children(engine::Engine, parent::NodeObj, def::Dict{Symbol, Any})
	if haskey(def, :children)
		children = def[:children]
		for c in children
			child = load_def(engine, c)
			set_parent(child, parent)
		end
	end
	for (id, child) in parent.children
		inited(child)
	end
	inited(parent)
	parent
end

inited(obj::BaseObj) = nothing

for_children(f::Function, leaf::LeafObj, preorder::Bool = false) = f(leaf)
function for_children(f::Function, node::NodeObj, preorder::Bool = false)
	preorder && f(node)
	for (id, child) in node.children
		for_children(f, child, preorder)
	end
	!preorder && f(node)
end

render(leaf::LeafObj, engine::Engine) = nothing
get_local_bound(obj::LeafObj) = Empty{Float32}()

function get_local_transform(node::NodeObj)
	!haskey(node.children, :spatial) && return eye(Float32, 4)
	get_local_transform(node.children[:spatial])
end

function get_local_bound(node::NodeObj)
	!haskey(obj.children, :spatial) && return Empty{Float32}()
	get_local_bound(obj.children[:spatial])
end

function calc_local_bound(node::NodeObj, leafOnly::Bool = true)
	bound = Empty{Float32}()
	for (id, c) in node.children
		leafOnly && !isa(c, LeafObj) && continue
		localBound = get_local_bound(c)
		localBound == Empty{Float32}() && continue
		if bound == Empty{Float32}()
			bound = localBound
		else
			union!(bound, localBound)
		end
	end
	bound
end

function get_world_transform(node::NodeObj)
	!haskey(node.children, :spatial) && return eye(Float32, 4)
	get_world_transform(node.children[:spatial])
end

function get_world_bound(obj::NodeObj)
	!haskey(obj.children, :spatial) && return Empty{Float32}()
	get_world_bound(obj.children[:spatial])
end

import .Octree.getbound
getbound(obj::NodeObj) = convert(AABB{Float32}, get_world_bound(obj))


type Object <: NodeObj
	id::Symbol
	parent::NodeObj
	children::Dict{Symbol, BaseObj}

	Object(id::Symbol) = new(id, NoNode(), Dict{Symbol, BaseObj}())
end

function init(engine::Engine, ::Type{Object}, def::Dict{Symbol, Any})::Object
	obj = Object(get_id!(def))
	init_children(engine, obj, def)
	inited(obj)
	obj
end

function inited(obj::Object)
	if haskey(obj.children, :spatial)
		bound = calc_local_bound(obj)
		set_local_bound(obj.children[:spatial], bound)
	end
end

function added_child(parent::NodeObj, obj::Object)
	world = top(parent)
	!isa(world, BaseWorld) && return
	for_children(obj, true) do child
		add_to_world(world, child)
	end
end

function removing_child(parent::NodeObj, obj::Object)
	world = top(parent)
	!isa(world, BaseWorld) && return
	for_children(obj, false) do child
		remove_from_world(world, child)
	end
end

function render(obj::Object, engine::Engine)
	for (id, child) in obj.children
		if isa(child, LeafObj)
			render(child, engine)
		end
	end
end
