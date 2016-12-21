immutable HandlerData
	user::Any
	func::Function
end

typealias EventHandlers Dict{Symbol, Vector{HandlerData}}

get_events(owner) = owner.events

function add_event(handler::Function, owner, event::Symbol, user = nothing)
	handlers = get!(get_events(owner), event) do; HandlerData[] end
	push!(handlers, HandlerData(user, handler))
	handler
end

function remove_event(handler::Function, owner, event::Symbol)
	handlers = get_events(owner)[event]
	deleteat!(handlers, findfirst(h->h.func == handler, handlers))
	nothing
end

function remove_event(user, owner, event::Symbol)
	handlers = get_events(owner)[event]
	deleteat!(handlers, findfirst(h->h.user == user, handlers))
	nothing
end

function remove_events(user, owner)
	for (event, handlers) in get_events(owner)
		filter!(h->h.user != user, handlers)
	end
end

function call_event(owner, event::Symbol, args...)
	#info("call_event $(get_id(owner)) $event")
	handlers = get!(get_events(owner), event) do; Function[] end
	for h in handlers
		h.func(owner, event, args...)
	end
	#info("call_event $(get_id(owner)) $event done")
	nothing
end
