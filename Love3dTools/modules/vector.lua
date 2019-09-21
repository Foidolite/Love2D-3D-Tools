--contains a definition for a vector class of arbitrary dimension
local Vector = {}

--constructor
function Vector:new(o)
    o = o or {}
    o.x = o[1]
    o.y = o[2]
    o.z = o[3]
    o.X = o[1]
    o.Y = o[2]
    o.Z = o[3]
    
    setmetatable(o, self)
    self.__index = self
    
    return o
end

--metamethods for basic component arithmetic
function Vector.__add(a, b)
    if #a == #b then
        local c = {}
        for i,v in ipairs(a) do
            c[i] = a[i] + b[i]
        end
        return Vector:new(c)
    end
    error("Attempt to add vectors of different dimension")
end

function Vector.__mul(a, b)
    local c = {}
    if type(a) == "number" then
        for i,v in ipairs(b) do
           c[i] = a * b[i] 
        end
    else
        for i,v in ipairs(a) do
           c[i] = b * a[i] 
        end
    end
    return Vector:new(c)
end

function Vector.__div(a,b)
    local c = {}
    if type(a) == "number" then
        error("Cannot divide number by vector")
    end
    for i,v in ipairs(a) do
        c[i] = b[i] / a
    end
    return Vector:new(c)
end

function Vector.__sub(a, b)
    if #a == #b then
        local c = {}
        for i,v in ipairs(a) do
            c[i] = a[i] - b[i]
        end
        return Vector:new(c)
    end
    error("Attempt to subtract vectors of different dimension")
end

function Vector.__unm(a)
    local c = {}
    for i,v in ipairs(a) do
        c[i] = -a[i]
    end
    return Vector:new(c)
end

--dot product
function Vector:dot(b)
    if #self == #b then
        local c = 0
        for i,v in ipairs(self) do
            c = c + v * b[i]
        end
        return c
    end
    error("Attempt to perform dot product on vectors of different dimension")
end

--cross product
function Vector:cross(b)
    --sanitizations
    if #b == nil then --in case a table was supplied
        b = Vector:new(b)
    end
    if #b ~= 3 then --if 2d cross is desired, simply supply z = 0 if crossing w/ vector and z = b if crossing w/ scalar.
        error("Cross product is undefinable for dimensions other than 3")
    end
    local a = {self[1], self[2], self[3]}
    if #self ~= 3 then
       error("Cross product is undefinable for dimensions other than 3") 
    end
    
    --calculations
    local c = {}
    c[1] = a[2]*b[3] - a[3]*b[2]
    c[2] = a[3]*b[1] - a[1]*b[3]
    c[3] = a[1]*b[2] - a[2]*b[1]
    
    return Vector:new(c)
end

--miscellaneous other functions
function Vector:magnitude()
    local c = 0
    for i,v in ipairs(self) do
        c = c + v^2
    end
    return math.sqrt(c)
end

function Vector:unit()
    local c = {}
    local m = self:magnitude()
    for i,v in ipairs(self) do
        c[i] = v / m
    end
    return Vector:new(c)
end

return Vector