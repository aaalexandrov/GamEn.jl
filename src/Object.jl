abstract BaseObj

abstract LeafObj <: BaseObj

abstract NodeObj <: BaseObj

get_parent(obj::BaseObj)::Nullable{NodeObj} = obj.parent

function set_parent(child::BaseObj, parent::Nullable{NodeObj} = Nullable{NodeObj}())
	if !isnull(child.parent)
		@assert get(child.parent).children[child.id] == child
		delete!(get(child.parent).children, child.id)
	end
	child.parent = parent
	if !isnull(parent)
		@assert !haskey(get(parent).children, child.id)
		get(parent).children[child.id] = child
	end
end

get_children(parent::NodeObj, typ::Type) = filter(c->isa(c, typ), parent.children)

hasposition(obj::BaseObj) = false
