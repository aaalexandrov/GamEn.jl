typealias EventHandlers Dict{Symbol, Vector{Function}}

get_events(owner) = owner.events

function add_event(handler::Function, owner, event::Symbol)
	handlers = get!(get_events(owner), event) do; Function[] end
	push!(handlers, handler)
	handler
end

function remove_event(handler::Function, owner, event::Symbol)
	handlers = get_events(owner)[event]
	deleteat!(handlers, findfirst(handlers, handler))
	nothing
end

function call_event(owner, event::Symbol, args...)
	handlers = get!(get_events(owner), event) do; Function[] end
	for h in handlers
		h(owner, event, args...)
	end
	nothing
end
