local Vector = require("vector")
--defines a class for matrices of arbitrary dimension, stored in column-major form
local Matrix = {columns = 0, rows = 0}

--constructor
function Matrix:new(t)
    local o = t or {}
    o.columns = #t
    if #t ~= 0 then
       o.rows = #t[1] 
    end
    --sanitize table
    for i,v in ipairs(o) do
        if #v ~= o.rows then
            error("Matrices must be rectangular")
        end
    end
    
    setmetatable(o, self)
    self.__index = self
    
    return o
end

--construct empty matrix by size
function Matrix:newSize(m, n)
    local o = {}
    o.columns = n
    o.rows = m
    for i = 1, n do
        local c = {}
        for j = 1, m do
            c[j] = 0
        end
        o[i] = c
    end
    
    setmetatable(o, self)
    self.__index = self
    
    return o
end

--vector transformation
function Matrix:transform(b)
    if #b == self.columns then
        local c = {}
        for i = 1, self.rows do
            c[i] = 0
        end
        for i,v in ipairs(self) do
            for j,w in ipairs(v) do
                c[j] = c[j] + b[i]*w
            end
        end
        return Vector:new(c)
    end
    error("Supplied vector's dimension does not match number of columns in matrix")
end

--matrix multiplication, applying this on onto another
function Matrix:apply(b)
    if b.rows == self.columns then
        local c = {}
        for i,v in ipairs(b) do
            c[i] = self:transform(v)
        end
        return Matrix:new(c)
    end
    error("Attempt to apply matrix onto another matrix with more or less rows than the first has columns")
end

--conversion to row-major form
function Matrix:rowMajor()
    local b = {}
    for i = 1, self.rows do
        b[i] = {}
        for j,v in ipairs(self) do
            b[i][j] = v[i]
        end
    end
    return Matrix:new(b)
end

--conversion to 1d table
function Matrix:flat()
    local b = {}
    for i,v in ipairs(self) do
        for j,w in ipairs(v) do
            b[(i-1)*self.rows + j] = w
        end
    end
    return b --this is no longer a "matrix" as we've defined, so a new matrix is not constructed.
end

--functions for the computation of openGL transformation matrices

--transcribes this matrix onto another
function Matrix:transcribe(b)
    for i,v in ipairs(self) do
        if i > b.columns then
            break
        end
        for j,w in ipairs(v) do
            if j > b.rows then
                break
            end
            b[i][j] = w
        end
    end
end

--generates a 3x3 total rotation matrix based on the rotation vector supplied
function Matrix.generateRotMatrix(rotation, ext)
    if ext == nil then
        ext = true --default extrinsic rotation
    end
    --define rotation matrices for all three axes of rotation and their inverses
    local sin, cos = math.sin(rotation[1]), math.cos(rotation[1])
    local xRot = Matrix:new({{1, 0, 0}, {0, cos, sin}, {0, -sin, cos}})
    sin, cos = math.sin(-rotation[1]), math.cos(-rotation[1])
    local unxRot = Matrix:new({{1, 0, 0}, {0, cos, sin}, {0, -sin, cos}})
    sin, cos = math.sin(rotation[2]), math.cos(rotation[2])
    local yRot = Matrix:new({{cos, 0, -sin}, {0, 1, 0}, {sin, 0, cos}})
    sin, cos = math.sin(-rotation[2]), math.cos(-rotation[2])
    local unyRot = Matrix:new({{cos, 0, -sin}, {0, 1, 0}, {sin, 0, cos}})
    sin, cos = math.sin(rotation[3]), math.cos(rotation[3])
    local zRot = Matrix:new({{cos, sin, 0}, {-sin, cos, 0}, {0, 0, 1}})
    sin, cos = math.sin(-rotation[3]), math.cos(-rotation[3])
    local unzRot = Matrix:new({{cos, sin, 0}, {-sin, cos, 0}, {0, 0, 1}})
    
    local totalRot, totalUnRot = {}, {}
    if ext then --extrinsic or intrinsic rotation
        totalRot = xRot:apply(yRot:apply(zRot)) --compound them
        totalUnRot = unzRot:apply(unyRot:apply(unxRot)) --find the inverse as well
    else
        totalRot = zRot:apply(yRot:apply(xRot)) --compound them
        totalUnRot = unxRot:apply(unyRot:apply(unzRot)) --find the inverse as well
    end
    
    return totalRot, totalUnRot
end

--generates an openGL transformation matrix
function Matrix:generatePosRot(translation)
    local c = Matrix:newSize(4, 4)
    self:transcribe(c)
    c[4][1] = translation[1]
    c[4][2] = translation[2]
    c[4][3] = translation[3]
    c[4][4] = 1
    return c
end

return Matrix