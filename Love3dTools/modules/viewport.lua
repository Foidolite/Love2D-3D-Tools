local Vector = require("vector")
local Matrix = require("matrix")

--a 3d Viewport class
local ViewPort = {}
ViewPort.near, ViewPort.far = 0.0625, 512.0625 --near and far clipping distance
ViewPort.width, ViewPort.height = 1920, 1080 --dimensions of the rendering surface at the top of the frustrum.
--focal distance calculations for controlling FOV. FOV = 2*atan(w*fd/h), so fd = tan(FOV/2)*(h/w)
ViewPort.FOVdeg = 90 --use this to modulate FOV in degrees
ViewPort.FOV = ViewPort.FOVdeg * (math.pi/180)
ViewPort.fd = math.tan(ViewPort.FOV/2) * (ViewPort.height / ViewPort.width)
--A projection matrix that should map space so that x is right, y is forwards, and z is up. Left empty here but filled below.
ViewPort.proj = Matrix:new({}) 
--position and rotation
ViewPort.position = Vector:new({0, 0, 0}) --internal position
ViewPort.rotation = Vector:new({0, 0, 0}) --internal rotation
ViewPort.posrot = Matrix:new({{1,0,0,0},{0,1,0,0},{0,0,1,0},{0,0,0,1}}) --matrix applied to transform ViewPort posrot
--blinn-phong shader with shadows and support for multiple lights
ViewPort.shader = love.graphics.newShader [[
    extern mat4 proj;
    extern mat4 model;
    extern vec3 cameraPosition;
    extern float renderDist;
    extern vec4 atmColor;
    const int numLights = 10;
    extern vec3 light_pos[numLights];
    extern vec4 light_iSpecs[numLights];
    extern vec4 light_iDiffs[numLights];
    extern float light_atts[numLights];
    extern vec4 iAmb;
    extern float mat_spec;
    extern float mat_diff;
    extern float mat_amb;
    extern float mat_alpha;
    extern CubeImage depthCubes[numLights];
    extern bool hasShadows[numLights];
    
    varying vec3 N;
    varying vec4 vPosition;
    
    #ifdef VERTEX
    attribute vec3 VertexNormal;
    
    vec4 position(mat4 transform, vec4 vertex)
    {
      vec3 normal = normalize((model * vec4(VertexNormal, 0)).xyz);
      N = normal;
      vPosition = model * vertex;
      
      return proj * model * vertex;
    }
    #endif
    
    #ifdef PIXEL
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) 
    {
        vec4 texturecolor = Texel(texture, texture_coords);
        vec4 o = color*texturecolor;
        float alpha = o.w;
        vec4 Iprobe = vec4(0,0,0,1);
        vec4 I = mat_amb*iAmb;
        float distView = distance(vPosition.xyz, cameraPosition);
        for (int i = 0; i < numLights; i += 1)
        {
            if (light_atts[i] <= 0)
                continue;
            float distLight = distance(vPosition.xyz, light_pos[i]);
            //evaluate all blinn-phong vectors
            vec3 L = normalize(light_pos[i] - vPosition.xyz);
            vec3 V = normalize(cameraPosition - vPosition.xyz);
            vec3 H = normalize(L + V);
            //evaluate illumination
            vec4 Ii = vec4(0,0,0,1);
            if (dot(L,N) > 0)
            {
                Ii = Ii + mat_diff*dot(L,N)*light_iDiffs[i]; //diffuse
                if (dot(H, N) > 0)
                    Ii = Ii + mat_spec*pow(dot(H, N), mat_alpha)*light_iSpecs[i]; //specular
            }
            //evaluate attenuation
            float att = 1/pow(distLight/light_atts[i] + 1, 2); //attenuation
            Ii = Ii * att;
            
            //shadow mapping
            if (hasShadows[i])
            {
                vec3 direction = vPosition.xyz - light_pos[i];
                //PCF
                vec3 sampleOffsetDirections[20] = vec3[]
                (
                   vec3( 1,  1,  1), vec3( 1, -1,  1), vec3(-1, -1,  1), vec3(-1,  1,  1), 
                   vec3( 1,  1, -1), vec3( 1, -1, -1), vec3(-1, -1, -1), vec3(-1,  1, -1),
                   vec3( 1,  1,  0), vec3( 1, -1,  0), vec3(-1, -1,  0), vec3(-1,  1,  0),
                   vec3( 1,  0,  1), vec3(-1,  0,  1), vec3( 1,  0, -1), vec3(-1,  0, -1),
                   vec3( 0,  1,  1), vec3( 0, -1,  1), vec3( 0, -1, -1), vec3( 0,  1, -1)
                ); 
                float shadow = 0;
                float samples = 20;
                float bias = 0.1;
                float diskRadius = 0.025;
                for (int j = 0; j < samples; ++j)
                {
                    vec4 shadowDist = Texel(depthCubes[i], direction + diskRadius*normalize(sampleOffsetDirections[j]));
                    if (distLight > shadowDist.x + bias)
                        shadow += 1.0;
                }
                shadow /= samples;
                Ii = Ii / (shadow + 1);
            }
            
            I += Ii;
        }
        //compute final color by overlaying illumination onto texturecolor
        float A = dot(o, vec4(1/3,1/3,1/3,0));
        if (A < 0.5) 
            o = 2 * o * I;
        else
            o = vec4(1,1,1,1) - 2*(vec4(1,1,1,1) - o)*(vec4(1,1,1,1) - I);
        //apply atmosphere
        float atm = (max(distView - renderDist/2, 0)/renderDist); 
        o = (o*(1-atm) + atmColor*atm);
        
        return vec4(o.xyz, alpha);
    }
    #endif
]]

--send list of lights to this function to format lights properly for the shader
function ViewPort:makeLights(lights, max, defaultDepthCube, viewName)
    posString = viewName .. ".shader:send(\"light_pos\""
    specString = viewName .. ".shader:send(\"light_iSpecs\""
    diffString = viewName .. ".shader:send(\"light_iDiffs\""
    attString = viewName .. ".shader:send(\"light_atts\""
    cubes = {}
    shadowString = viewName .. ".shader:send(\"hasShadows\""
    for i = 1, max do
        if lights[i] == nil then
            posString = posString .. ", {0,0,0}"
            specString = specString .. ", {1,1,1,1}"
            diffString = diffString .. ", {1,1,1,1}"
            attString = attString .. ", -1"
            table.insert(cubes, defaultDepthCube)
            shadowString = shadowString .. ", false"
        else
            local pos = lights[i].pos or {0, 0, 0}
            local iDiff = lights[i].iDiff or {1,1,1,1}
            local iSpec = lights[i].iSpec or iDiff or {1,1,1,1}
            local att = lights[i].att or 50
            local cube = lights[i].depthCube or defaultDepthCube
            table.insert(cubes, cube)
            local shadow = lights[i].shadow or true
            posString = posString .. ", {" .. pos[1] .. "," .. pos[2] .. "," .. pos[3] .. "}"
            specString = specString .. ", {" .. iSpec[1] .. "," .. iSpec[2] .. "," .. iSpec[3] .. "," .. iSpec[4] .. "}"
            diffString = diffString .. ", {" .. iDiff[1] .. "," .. iDiff[2] .. "," .. iDiff[3] .. "," .. iDiff[4] .. "}"
            attString = attString .. ", " .. att
            shadowString = shadowString .. ", " .. tostring(shadow)
        end
    end
    loadstring(posString .. ")")()
    loadstring(specString .. ")")()
    loadstring(diffString .. ")")()
    loadstring(attString .. ")")()
    self.shader:send("depthCubes", cubes[1], cubes[2], cubes[3], cubes[4], cubes[5], cubes[6], cubes[7], cubes[8], cubes[9], cubes[10])
    loadstring(shadowString .. ")")()
end

--depth shader
ViewPort.depthShader = love.graphics.newShader [[
    extern mat4 proj;
    extern mat4 model;
    extern vec3 lightPosition;
    
    varying float dist;
    
    #ifdef VERTEX
    vec4 position(mat4 transform, vec4 vertex)
    {
        dist = distance((model * vertex).xyz, lightPosition);
      
        return proj * model * vertex;
    }
    #endif
    
    #ifdef PIXEL
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) 
    {
        return vec4(dist, 0, 0, 1);
    }
    #endif
]]

--blinn phong shader without shadows
ViewPort.shaderBlPh = love.graphics.newShader [[
    extern mat4 proj;
    extern mat4 model;
    extern vec3 cameraPosition;
    extern float renderDist;
    extern vec4 atmColor;
    extern vec3 light_pos;
    extern vec4 light_iSpec;
    extern vec4 light_iDiff;
    extern float light_att;
    extern float mat_spec;
    extern float mat_diff;
    extern float mat_amb;
    extern float mat_alpha;
    
    varying float dist;
    varying vec3 N;
    varying vec4 vPosition;
    
    #ifdef VERTEX
    attribute vec3 VertexNormal;
    
    vec4 position(mat4 transform, vec4 vertex)
    {
      dist = distance((model * VertexPosition).xyz, cameraPosition);
      vec3 normal = normalize((model * vec4(VertexNormal, 0)).xyz);
      N = normal;
      vPosition = model * vertex;
      
      return proj * model * vertex;
    }
    #endif
    
    #ifdef PIXEL
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) 
    {
        vec4 texturecolor = Texel(texture, texture_coords);
        vec4 o = color*texturecolor;
        float alpha = o.w;
        vec4 iAmb = vec4(1,1,1,1);
        //evaluate all necessary vectors
        vec3 L = normalize(light_pos - vPosition.xyz);
        vec3 R = 2*dot(L, N)*N - L; //not used in the blinn-phong shader, but here in case necessary
        vec3 V = normalize(cameraPosition - vPosition.xyz);
        vec3 H = normalize(L + V);
        //evaluate illumination
        vec4 I = mat_amb*iAmb; //ambient
        if (dot(L,N) > 0)
        {
            I = I + mat_diff*dot(L,N)*light_iDiff; //diffuse
            if (dot(R, V) > 0)
                I = I + mat_spec*pow(dot(H, N), mat_alpha)*light_iSpec; //specular
        }
        //compute final color by overlaying illumination onto texturecolor
        float A = dot(o, vec4(1/3,1/3,1/3,0));
        if (A < 0.5) 
            o = 2 * o * I;
        else
            o = vec4(1,1,1,1) - 2*(vec4(1,1,1,1) - o)*(vec4(1,1,1,1) - I);
        float atm = (max(dist - renderDist/2, 0)/renderDist); //atmosphere
        float att = 1/pow(dist/light_att + 1, 2); //attenuation
        o = o * att;
        return vec4((o*(1-atm) + atmColor*atm).xyz, alpha);
    }
    #endif
]]

--constructor
function ViewPort:new(t)
    local o = t or {}
    
    setmetatable(o, self)
    self.__index = self
    
    o:recalibrateProj()
    
    return o
end

--update light depth shader and return depth cube texture
function ViewPort:makeDepthCube(world, pos, faces)
    local FOV = math.pi/2
    local fd = math.tan(FOV/2)
    local proj = Matrix:new({{1 / (1 * fd), 0, 0, 0},
                            {0, 0, (self.far + self.near) / (self.far - self.near), 1},
                            {0, 1 / fd, 0, 0},
                            {0, 0, -2*self.far*self.near / (self.far - self.near), 0}})
    local rotations = {Vector:new({0,-math.pi/2,math.pi/2}),Vector:new({0,math.pi/2,-math.pi/2}),Vector:new({0,0,0}),Vector:new({0,math.pi,math.pi}),Vector:new({-math.pi/2,0,0}),Vector:new({math.pi/2,0,math.pi})}
    
    local depthCube = love.graphics.newCanvas(2048, 2048, {type = "cube", format = "r32f"})
    for i = 1, 6 do
        local totalRot, totalUnRot = Matrix.generateRotMatrix(rotations[i])
        local unRottedPos = -totalRot:transform(pos)
    
        local posrot = totalRot:generatePosRot(unRottedPos)
        local result = proj:apply(posrot)
        local r = result:rowMajor():flat() --convert result into row-major, 1d table
        
        self.depthShader:send("proj", r)
        self.depthShader:send("lightPosition", pos)
        
        love.graphics.setCanvas({{depthCube, face = i}, depthstencil = love.graphics.newCanvas(2048, 2048, {format = "depth16"})})
        love.graphics.setShader(self.depthShader)
        for i,v in ipairs(world) do
            v:updatePosRot()
            view.depthShader:send("model", v.posrot:rowMajor():flat())
            v:draw()
        end
        love.graphics.setShader()
        love.graphics.setCanvas()
    end
    
    return depthCube
end

--recalibrate projection matrix with focal point, width, height, and clipping distances.
function ViewPort:recalibrateProj()
    self.FOV = self.FOVdeg * (math.pi/180)
    self.fd = math.tan(self.FOV/2) * (self.height / self.width)
    self.proj = Matrix:new({{self.height / (self.width * self.fd), 0, 0, 0},
                            {0, 0, (self.far + self.near) / (self.far - self.near), 1},
                            {0, 1 / self.fd, 0, 0},
                            {0, 0, -2*self.far*self.near / (self.far - self.near), 0}})
end

function ViewPort:getRotMatrix()
    return Matrix.generateRotMatrix(self.rotation)
end

function ViewPort:updatePosRot()
    local totalRot, totalUnRot = self:getRotMatrix()
    local unRottedPos = -totalRot:transform(self.position)
    
    self.posrot = totalRot:generatePosRot(unRottedPos)
end

--send shader any new things it needs to know. e.g. new viewport position & rotation, new proj matrix, new lighting angle, etc.
function ViewPort:updateShader()
    self:recalibrateProj()
    self:updatePosRot()
    local result = self.proj:apply(self.posrot)
    local r = result:rowMajor():flat() --convert result into row-major, 1d table
    
    self.shader:send("proj", r)
    self.shader:send("cameraPosition", self.position)
end

--set viewport
function ViewPort:set()
    love.graphics.setShader(self.shader)
end

--unset viewport
function ViewPort:unset()
    love.graphics.setShader()
end

return ViewPort