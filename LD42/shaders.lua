return setmetatable({}, {__index = function(t, name)
    return love.filesystem.read("shaders/" .. name .. ".glsl")
end})
