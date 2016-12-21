abstract BaseObj

abstract LeafObj <: BaseObj

abstract NodeObj <: BaseObj

type NoNode <: NodeObj
end

get_id(obj::BaseObj) = obj.id

function set_parent(child::BaseObj, parent::NodeObj = NoNode())
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

function init_children(engine::Engine, parent::NodeObj, def::Dict{Symbol, Any})
	#info("init_children $(get_id(parent))")
	if haskey(def, :children)
		children = def[:children]
		for c in children
			child = load_def(engine, c)
			set_parent(child, parent)
		end
	end
	#info("init_children $(get_id(parent)) done")
	parent
end

render(leaf::LeafObj, engine::Engine) = nothing

has_transform(obj::LeafObj) = false
has_transform(node::NodeObj) = haskey(node.children, :spatial)

get_local_bound(obj::LeafObj) = Empty{Float32}()
function get_local_bound(node::NodeObj)
	!haskey(obj.children, :spatial) && return Empty{Float32}()
	get_local_bound(obj.children[:spatial])
end

function calc_local_bound(node::NodeObj, leafOnly::Bool = true)
	#info("calc_local_bound $(get_id(node)) $(length(node.children))")
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

function gettransform(obj::NodeObj)
	!haskey(obj.children, :spatial) && return eye(Float32, 4)
	get_world_transform(obj.children[:spatial])[2]
end

import .Octree.getbound
function getbound(obj::NodeObj)
	!haskey(obj.children, :spatial) && return empty!(AABB{Float32}())
	convert(AABB{Float32}, get_world_bound(obj.children[:spatial]))
end

function child_added(node::NodeObj, child::BaseObj)
	call_event(node, :child_added, child)
end

function child_removed(node::NodeObj, child::BaseObj)
	call_event(node, :child_removed, child)
end

for_children(f::Function, obj::LeafObj) = f(obj)
function for_children(f::Function, node::NodeObj, preorder::Bool = true)
	if preorder
		f(node)
	end
	for (id, child) in node.children
		f(child)
	end
	if !preorder
		f(node)
	end
end

type Object <: NodeObj
	id::Symbol
	parent::NodeObj
	children::Dict{Symbol, BaseObj}
	events::EventHandlers

	Object(id::Symbol) = new(id, NoNode(), Dict{Symbol, BaseObj}(), EventHandlers())
end

function init(engine::Engine, ::Type{Object}, def::Dict{Symbol, Any})::Object
	obj = Object(get_id!(def))
	init_children(engine, obj, def)
	obj
end

function render(obj::Object, engine::Engine)
	#info("rendering Object $(obj.id)")
	for (id, child) in obj.children
		if isa(child, LeafObj)
			render(child, engine)
		end
	end
end
