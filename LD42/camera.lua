local terrain = require("terrain")

local camera = {}

camera.transform = kaun.newTransform()
setmetatable(camera, {__index = function(tbl, key)
    if camera.transform[key] then
        return function(...)
            return camera.transform[key](camera.transform, ...)
        end
    end
end})
camera.position = vec3(0, 0, 0)

function camera.uncollide()
    camera.position.y = math.max(camera.position.y,
        terrain.getHeight(camera.position.x, camera.position.z) + 0.25)
end

function camera.update(dt)
    local lk = love.keyboard
    local speed = 2.0
    if lk.isDown("lshift") then speed = 4.0 end
    speed = speed * dt

    local move = vec3(0, 0, 0)
    move.x = bool2Int(lk.isDown("d")) - bool2Int(lk.isDown("a"))
    move.y = bool2Int(lk.isDown("r")) - bool2Int(lk.isDown("f"))
    move.z = bool2Int(lk.isDown("s")) - bool2Int(lk.isDown("w"))

    if move:len() > 0.5 then
        local moveY = move.y
        move = vec3(camera.localDirToWorld(move.x, move.y, move.z))
        move.y = move.y + moveY -- move up down with r/f in world space
        camera.position = camera.position + move:normalize() * speed
    end

    camera.uncollide()
end

function camera.updatePlayer(playerPos)
    local rel = playerPos - camera.position
    rel.y = 0
    local maxDist = 3.0
    if rel:len() > maxDist then
        camera.position = camera.position + rel:normalize() * (rel:len() - maxDist)
    end
    camera.lookAt(playerPos:unpack())
    camera.uncollide()
end

function camera.mouseLook(dx, dy, sensitity)
    camera.rotateWorld(sensitity * dx, 0, 1, 0)
    camera.rotate(sensitity * dy, 1, 0, 0)
end

function camera.getTransform()
    camera.transform:setPosition(camera.position:unpack())
    return camera.transform
end

return camera
