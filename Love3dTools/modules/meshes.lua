local Vector = require("vector")
local Matrix = require("matrix")
--various mesh objects that can be used in a 3d world

--An "empty"; contains only rotation, scale, and position information
local Model = {}

--constructor
function Model:new(t)
    local o = t or {}
    
    o.rotation = Vector:new({0, 0, 0})
    o.position = Vector:new({0, 0, 0})
    o.scale = Vector:new({1, 1, 1})
    o.posrot = Matrix:newSize(4, 4)
    
    setmetatable(o, self)
    self.__index = self
    
    return o
end

function Model:getRotMatrix()
    return Matrix.generateRotMatrix(self.rotation)
end

function Model:updatePosRot()
    local totalRot = self:getRotMatrix()
    for i = 1,3 do
        for j = 1,3 do
            totalRot[i][j] = totalRot[i][j] * self.scale[i]
        end
    end
    
    self.posrot = totalRot:generatePosRot(self.position)
end

--A generic mesh type.
local Mesh = {defaultVertexFormat = {{"VertexPosition", "float", 3},{"VertexTexCoord", "float", 2},{"VertexNormal", "float", 3}},
        defaultMaterial = {spec = 0.3, diff = 0.8, amb = 0.1, alpha = 8}}
Mesh = Model:new(Mesh)

--generic constructor
function Mesh:new(o)
    o = o or {}
    
    o = Model:new(o)
    
    setmetatable(o, self)
    self.__index = self
    
    return o
end

--construct from .obj. only triangular faces permitted
function Mesh:newFromFile(obj, texture)
    local info = love.filesystem.getInfo(obj)
    
    if info == nil then
        error("Obj file does not exist")
    end
    
    local lines = {}
    for line in love.filesystem.lines(obj) do
        table.insert(lines, line)
    end
    
    local v, vt, vn, f = {}, {}, {}, {}
    
    for _, line in ipairs(lines) do
        local l = string_split(line)
        
        if l[1] == "v" then--vertex position
            local vertex = {tonumber(l[2]), tonumber(l[3]), tonumber(l[4])}
            table.insert(v, vertex)
        elseif l[1] == "vt" then --vertex texture
            local uv = {tonumber(l[2]), tonumber(l[3])}
            table.insert(vt, uv)
        elseif l[1] == "vn" then --vertex normal
            local norm = {tonumber(l[2]), tonumber(l[3]), tonumber(l[4])}
            table.insert(vn, norm)
        elseif l[1] == "f" then --face
            local face = {l[2], l[3], l[4]}
            table.insert(f, face)
        end
    end
    
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.mesh = love.graphics.newMesh(Mesh.defaultVertexFormat, 3*#f, "triangles", "static")
    o.mesh:setTexture(texture)
    o:setVmap(3*#f)
    
    for i,face in ipairs(f) do
        for j = 1, 3 do
            local ins = string_split(face[j], "/")
            ins[1] = tonumber(ins[1])
            ins[2] = tonumber(ins[2])
            ins[3] = tonumber(ins[3])
            o.mesh:setVertex((i-1)*3 + j, v[ins[1]][1], v[ins[1]][2], v[ins[1]][3],
                            vt[ins[2]][1], 1 - vt[ins[2]][2], vn[ins[3]][1], vn[ins[3]][2], vn[ins[3]][3])
        end
    end
    
    return o
end

--set the vertex index map to however many active vertices currently exist
function Mesh:setVmap(n)
    self.vmap = {}
    for i = 1, n do
        self.vmap[i] = i
    end
    self.mesh:setVertexMap(self.vmap)
    self.mesh:setDrawRange(1, n)
end

function Mesh:draw()
    love.graphics.draw(self.mesh, 0, 0)
end

--a generic type for polygons. Maximum 20 points.
local Poly = Mesh:new()

--generic constructor
function Poly:new(t)
    local o = t or {}
    
    o = Mesh:new(o)
    o.mesh = love.graphics.newMesh(Mesh.defaultVertexFormat, 20, "fan", "static")
    o.vmap = {}
    
    setmetatable(o, self)
    self.__index = self
    
    return o
end

--sized constructor
function Poly:newSize(n)
    local o = Poly:new()
    
    o.mesh = love.graphics.newMesh(Mesh.defaultVertexFormat, n, "fan", "static")
    o:setVmap(n)
    
    return o
end

--set vertices position, tex coord, and normal
function Poly:setVertices(t, texture, normal) --t should be a table of alternating vec3(position) and vec2(uv)
    self.mesh:setTexture(texture)
    for i = 1, #t, 2 do
        self.mesh:setVertex(math.ceil(i/2), t[i][1], t[i][2], t[i][3], t[i+1][1], t[i+1][2], normal[1], normal[2], normal[3])
    end
    self:setVmap(#t/2)
end

--a parallelogram quad
local ParaQuad = Poly:new()

--generic constructor
function ParaQuad:new(t)
    local o = t or {}
    
    o = Poly:newSize(4)
    
    setmetatable(o, self)
    self.__index = self
    
    return o
end

--specific constructor, supply three points clockwise w/ the first point at the top left of the texture and the third at the bottom right
function ParaQuad:newFromPts(texture, p1, p2, p3, uv1, uv3, uv2, uv4) --weird uv config: omit 4 for parallelogram omit 2 for rectangle.
    local o = ParaQuad:new()
    o.mesh:setTexture(texture)
    
    local normal = ((p1-p2):cross(p3-p2)):unit()
    local w,h = texture:getDimensions()
    p4 = Vector:new({p1[1] + p3[1] - p2[1], p1[2] + p3[2] - p2[2], p1[3] + p3[3] - p2[3]})
    uv2 = uv2 or Vector:new({uv3[1], uv1[2]})
    uv4 = uv4 or Vector:new({uv1[1] + uv3[1] - uv2[1], uv1[2] + uv3[2] - uv2[2]})
    o.mesh:setVertex(1, p1[1], p1[2], p1[3], uv1[1]/w, uv1[2]/h, normal[1], normal[2], normal[3])
    o.mesh:setVertex(2, p2[1], p2[2], p2[3], uv2[1]/w, uv2[2]/h, normal[1], normal[2], normal[3])
    o.mesh:setVertex(3, p3[1], p3[2], p3[3], uv3[1]/w, uv3[2]/h, normal[1], normal[2], normal[3])
    o.mesh:setVertex(4, p4[1], p4[2], p4[3], uv4[1]/w, uv4[2]/h, normal[1], normal[2], normal[3])
    
    return o
end

function string_split(s,d)
   d = d or "%s+"
   local t = {}
   local i = 0
   local f
   local match = '(.-)' .. d .. '()'
   if string.find(s, d) == nil then
      return {s}
   end
   for sub, j in string.gfind(s, match) do
         i = i + 1
         t[i] = sub
         f = j
   end
   if i~= 0 then
      t[i+1]=string.sub(s,f)
   end
   return t
end

return {Model, Mesh, Poly, ParaQuad}