type World <: NodeObj
  parent::Nullable{NodeObj}
  children::Dict{Symbol, BaseObj}
  octree::Octree.Tree{NodeObj, Float32}
end
