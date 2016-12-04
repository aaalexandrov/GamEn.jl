abstract BaseObj

abstract LeafObj <: BaseObj

abstract NodeObj <: BaseObj

type NoNode <: NodeObj
end

get_id(obj::BaseObj) = obj.id

function set_parent(child::BaseObj, parent::NodeObj = child)
	if child.parent != NoNode()
		child_removed(child.parent, child)
		@assert child.parent.children[get_id(child)] == child
		delete!(child.parent.children, get_id(child))
	end
	child.parent = parent
	if parent != NoNode()
		@assert !haskey(parent.children, get_id(child))
		parent.children[get_id(child)] = child
		child_added(child.parent, child)
	end
end

function top(obj::BaseObj)
	t = obj
	while t.parent != NoNode()
		t = t.parent
	end
	t
end

has_transform(obj::LeafObj) = false
has_transform(node::NodeObj) = haskey(node.children, :spatial)

function gettransform(obj::NodeObj)
	!haskey(obj.children, :spatial) && return eye(Float32, 4)
	get_world_transform(obj.children[:spatial])[2]
end

import .Octree.getbound
function getbound(obj::NodeObj)
	!haskey(obj.children, :spatial) && return empty!(AABB{Float32}())
	get_world_bound(obj.children[:spatial])
end

function child_added(node::NodeObj, child::BaseObj)
	call_event(node, :child_added, child)
end

function child_removed(node::NodeObj, child::BaseObj)
	call_event(node, :child_removed, child)
end

for_children(f::Function, obj::LeafObj) = f(obj)
function for_children(f::Function, node::NodeObj)
	f(node)
	foreach(f, node.children)
end

type Object <: NodeObj
	id::Symbol
	parent::NodeObj
	children::Dict{Symbol, BaseObj}
	events::EventHandlers

	Object(id::Symbol) = new(id, NoNode(), Dict{Symbol, BaseObj}(), EventHandlers())
end
