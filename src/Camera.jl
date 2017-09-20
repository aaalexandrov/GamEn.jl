abstract type AbstractCamera end

type FreeCamera <: AbstractCamera
	deltaTrans::Vector{Float32}
	deltaAngles::Vector{Float32}

	FreeCamera(deltaTrans::Vector{Float32}, deltaAngles::Vector{Float32}) = new(deltaTrans, deltaAngles)
end

function update(cam::GRU.Camera, trans::Vector{Float32}, angles::Vector{Float32})
	m = eye(Float32, 4, 4)
	Math3D.rotxyz(m, angles...)
	Math3D.trans(m, trans)
	GRU.settransform(cam, GRU.gettransform(cam)*m)
end

function process_input(engine::Engine, cam::FreeCamera)
	trans = Array{Float32}(3)
	angles = Array{Float32}(3)
	deltaTime = deltatime(engine)

	trans[1] = (GLFW.GetKey(engine.window, GLFW.KEY_D) - GLFW.GetKey(engine.window, GLFW.KEY_A)) * cam.deltaTrans[1] * deltaTime
	trans[2] = (GLFW.GetKey(engine.window, GLFW.KEY_F) - GLFW.GetKey(engine.window, GLFW.KEY_R)) * cam.deltaTrans[2] * deltaTime
	trans[3] = (GLFW.GetKey(engine.window, GLFW.KEY_W) - GLFW.GetKey(engine.window, GLFW.KEY_S)) * cam.deltaTrans[3] * deltaTime

	angles[1] = (GLFW.GetKey(engine.window, GLFW.KEY_G) - GLFW.GetKey(engine.window, GLFW.KEY_T)) * cam.deltaAngles[1] * deltaTime
	angles[2] = (GLFW.GetKey(engine.window, GLFW.KEY_E) - GLFW.GetKey(engine.window, GLFW.KEY_Q)) * cam.deltaAngles[2] * deltaTime
	angles[3] = (GLFW.GetKey(engine.window, GLFW.KEY_Z) - GLFW.GetKey(engine.window, GLFW.KEY_C)) * cam.deltaAngles[3] * deltaTime

	update(engine.renderer.camera, trans, angles)
end
