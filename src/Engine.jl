type Engine
  renderer::GRU.Renderer
  defs::Dict{String, Any}
  dataPath::String

  Engine(dataPath::String) = new(GRU.Renderer(), Dict{String, Any}(), dataPath)
end

function init(engine::Engine)

end
