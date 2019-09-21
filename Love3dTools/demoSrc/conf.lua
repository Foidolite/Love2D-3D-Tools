function love.conf(t)
	t.title = "3D demo"
	t.window.width = 1920
	t.window.height = 1080
    t.window.depth = 24 --this line must be present for depth testing to work on certain systems
end