Vector = require "vector"
Matrix = require "matrix"
ViewPort = require "viewport"
local Meshes = require "meshes"
Model, Mesh = Meshes[1], Meshes[2]

function love.load()
    --intialize camera
    view = ViewPort:new()
    view.shader:send("renderDist", 50) --object colors fade to atmColor at this distance
    view.shader:send("atmColor", {0,0,0,1})
    view.shader:send("iAmb", {0.25,0.25,0.25,1}) --all objects are shaded with at least this color
    view.position = Vector:new({0,0,2})
    --intialize world
    world = {}
    world[1] = Mesh:newFromFile("assets/plane.obj", love.graphics.newImage("assets/2.png"))
    world[1].position = Vector:new({0, 0, -1})
    world[2] = Mesh:newFromFile("assets/cubes.obj", love.graphics.newImage("assets/3.png"))
    --set depth testing
    love.graphics.setDepthMode("lequal", true)
    --create a point light with shadows (lights and shadows must be created after depth testing is set or lighting glitches may occur)
    local depthCube = view:makeDepthCube(world, {10, 20, 2}) 
    view:makeLights({{pos = {10,20,2}}}, 10, depthCube, "view")
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
    if key == "f" then
        love.window.setFullscreen(not love.window.getFullscreen())
    end
end

function love.update(dt)
    view:updateShader()
    --basic camera movement
    if love.keyboard.isDown("up") then
        view.rotation[1] = view.rotation[1] - dt
    elseif love.keyboard.isDown("down") then
        view.rotation[1] = view.rotation[1] + dt
    end
    if love.keyboard.isDown("left") then
        view.rotation[3] = view.rotation[3] - dt
    elseif love.keyboard.isDown("right") then
        view.rotation[3] = view.rotation[3] + dt
    end
    local totalRot, totalUnRot = view:getRotMatrix()
    if love.keyboard.isDown("w") then
        view.position = view.position + totalUnRot:transform(Vector:new({0, 5, 0}))*dt
    elseif love.keyboard.isDown("s") then
        view.position = view.position + totalUnRot:transform(Vector:new({0, -5, 0}))*dt
    end
    if love.keyboard.isDown("a") then
        view.position = view.position + totalUnRot:transform(Vector:new({-5, 0, 0}))*dt
    elseif love.keyboard.isDown("d") then
        view.position = view.position + totalUnRot:transform(Vector:new({5, 0, 0}))*dt
    end
    if love.keyboard.isDown("e") then
        view.position = view.position + totalUnRot:transform(Vector:new({0, 0, 5}))*dt
    elseif love.keyboard.isDown("q") then
        view.position = view.position + totalUnRot:transform(Vector:new({0, 0, -5}))*dt
    end
end

function love.draw()
    --rescaling
    local w,h = love.graphics.getDimensions()
    love.graphics.push()
    love.graphics.scale(w/1920,h/1080)
    
    --draw all meshes in world table
    view:set()
    for i,v in ipairs(world) do
        v:updatePosRot()
        view.shader:send("model", v.posrot:rowMajor():flat())
        local m = v.material or v.defaultMaterial
        view.shader:send("mat_spec", m.spec)
        view.shader:send("mat_diff", m.diff)
        view.shader:send("mat_amb", m.amb)
        view.shader:send("mat_alpha", m.alpha)
        v:draw()
    end
    view:unset()
    
    love.graphics.pop()
end