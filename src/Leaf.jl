type Transform <: LeafObj
	xformLocal::Matrix{Float32}
	xformWorld::Matrix{Float32}
	version, parentVersion::UInt
end

type Visual <: LeafObj
	visual::GRU.Renderable
end
