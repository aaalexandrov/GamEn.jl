module Octree

using Shapes
using Shapes: intersect, isvalid

type Node{T}
  subNodes::Array{Nullable{Node{T}}, 3}
  objects::Array{T, 1}

  Node() = new(fill(Nullable{Node{T}}(), 2, 2, 2), T[])
end

type Tree{T, F}
  bound::AABB{F}
  root::Node{T}
  minNodeSize::F
  canExpand::Bool
end

Tree{T, F}(::Type{T}, bound::AABB{F}; minNodeSize::F = F(16), canExpand::Bool = false) = Tree{T, F}(bound, Node{T}(), minNodeSize, canExpand)

function add{T, F}(octree::Tree{T, F}, obj::T)
  objBound = getbound(obj)
  @assert isvalid(objBound)
  @assert !any(x->isinf(x), objBound.p)
  if !inside(octree.bound, objBound)
    if octree.canExpand
      expand(octree, objBound)
      @assert inside(octree.bound, objBound)
    else
      error("Octree: Trying to add an object outside of tree bounds")
    end
  end
  add(octree.root, octree.bound, octree, obj, objBound)
end

function remove{T, F}(octree::Tree{T, F}, obj::T)
  objBound = getbound(obj)
  remove(octree.root, octree.bound, octree, obj, objBound)
end

for_overlapping{T, F}(f::Function, octree::Tree{T, F}, bound::AABB{F}) = for_overlapping(f, octree.root, octree.bound, bound)

function expand{T, F}(octree::Tree{T, F}, objBound::AABB{F})
  ind = Int[0, 0, 0]
  while true
    for i = 1:3
      if objBound.p[i, 1] < octree.bound.p[i, 1]
        ind[i] = 2
      elseif objBound.p[i, 2] > octree.bound.p[i, 2]
        ind[i] = 1
      else
        ind[i] = 0
      end
    end
    if all(x->x==0, ind)
      break;
    end
    for i = 1:3
      if ind[i] == 0 # In case the bound we want to fit doesn't exit a dimension, grow symmetrically around 0
        ind[i] = abs(octree.bound.p[i, 1]) < abs(octree.bound.p[i, 2]) ? 2 : 1;
      end
      sz = octree.bound.p[i, 2] - octree.bound.p[i, 1]
      if ind[i] == 1
        octree.bound.p[i, 2] += sz
      else
        @assert ind[i] == 2
        octree.bound.p[i, 1] -= sz
      end
    end
    newRoot = Node{T}()
    newRoot.subNodes[ind...] = octree.root
    octree.root = newRoot
  end
end

cansubdivide{T, F}(nodeBound::AABB{F}, octree::Tree{T, F}) = minimum(nodeBound.p[:, 2] - nodeBound.p[:, 1]) / 2 >= octree.minNodeSize


function getsubbound{F}(nodeBound::AABB{F}, ind::Vector{Int})
  subBound = AABB{F}()
  for i=1:3
    mid = (nodeBound.p[i, 1] + nodeBound.p[i, 2]) / 2
    subBound.p[i, ind[i]] = nodeBound.p[i, ind[i]]
    subBound.p[i, 3-ind[i]] = mid
  end
  return subBound
end

function getsubindex{F}(nodeBound::AABB{F}, objBound::AABB{F})
  @assert inside(nodeBound, objBound)
  ind = Int[]
  for i=1:3
    mid = (nodeBound.p[i, 1] + nodeBound.p[i, 2]) / 2
    if objBound.p[i, 2] <= mid
      push!(ind, 1)
    elseif objBound.p[i, 1] >= mid
      push!(ind, 2)
    else
      return ind
    end
  end
  return ind
end

function getsubnode{T, F}(node::Node{T}, nodeBound::AABB{F}, octree::Tree{T, F}, objBound::AABB{F}, create::Bool)
  if create && !cansubdivide(nodeBound, octree)
    return node, nodeBound
  end
  ind = getsubindex(nodeBound, objBound)
  if length(ind) != 3
    return node, nodeBound
  end
  subNode = node.subNodes[ind...]
  if isnull(subNode)
    if !create
      return node, nodeBound
    end
    subNode = Nullable(Node{T}())
    node.subNodes[ind...] = subNode
  end
  return get(subNode), getsubbound(nodeBound, ind)
end

function add{T, F}(node::Node{T}, nodeBound::AABB{F}, octree::Tree{T, F}, obj::T, objBound::AABB{F})
  subNode, subBound = getsubnode(node, nodeBound, octree, objBound, true)
  if subNode == node
    @assert findfirst(node.objects, obj) == 0
    push!(node.objects, obj)
  else
    add(subNode, subBound, octree, obj, objBound)
  end
end

function deleteat_unordered!{T}(v::Vector{T}, ind::Int)
  v[ind] = v[end]
  resize!(v, length(v)-1)
end

function remove{T, F}(node::Node{T}, nodeBound::AABB{F}, octree::Tree{T, F}, obj::T, objBound::AABB{F})
  subNode, subBound = getsubnode(node, nodeBound, octree, objBound, false)
  if subNode == node
    deleteat_unordered!(node.objects, findfirst(node.objects, obj))
  else
    remove(subNode, subBound, octree, obj, objBound)
  end
end

function for_overlapping{T, F}(f::Function, node::Node{T}, nodeBound::AABB{F}, bound::AABB{F})
  for obj in node.objects
    if intersect(bound, getbound(obj))
      f(obj)
    end
  end
  for z = 1:2, y = 1:2, x = 1:2
    if !isnull(node.subNodes[x, y, z])
      subBound = getsubbound(nodeBound, [x, y, z])
      if intersect(bound, subBound)
        for_overlapping(f, get(node.subNodes[x, y, z]), subBound, bound)
      end
    end
  end
end

#=
ab = AABB([-32.0, -32, -32], [32.0, 32, 32])
ab1 = AABB([-2.0, -2, -2], [-1.0, -1, -1])
ab5 = AABB([-5.0, -5, -5], [5.0, 5, 5])
ab10 = AABB([10.0, 10, 10], [12.0, 12, 12])
ab50 = AABB([50.0, 0, 10], [60.0, 10, 20])

getbound(ab::AABB) = ab

oc = Tree(typeof(ab5), ab; canExpand=true)
add(oc, ab5)
add(oc, ab1)
add(oc, ab10)
add(oc, ab50)
for_overlapping(oc, ab5) do ab
  println(ab)
end
remove(oc, ab5)
println()
for o in @async for_overlapping(x->produce(x), oc, oc.bound)
  println(o)
end
=#

end
