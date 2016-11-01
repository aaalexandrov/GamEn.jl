__precompile__()
module GamEn

import GRU
import JSON
import ObjGeom
import GLFW
import ModernGL

const GLHelper = GRU.GLHelper
const FTFont = GRU.FTFont
const Math3D = GRU.Math3D

include("Octree.jl")
include("Engine.jl")
include("Camera.jl")
include("Object.jl")
include("World.jl")
include("Init.jl")
include("Rendering.jl")

end
