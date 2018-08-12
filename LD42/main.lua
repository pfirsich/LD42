kaun = require("kaun")

cpml = require("libs.cpml")
vec3 = cpml.vec3
mat4 = cpml.mat4

local terrain = require("terrain")

local lightDir = {vec3(-0.8252, 0.3637, 0.4320):normalize():unpack()}
local ambientColor = {0.15, 0.16, 0.15}

local shaders = setmetatable({}, {__index = function(t, name)
    return love.filesystem.read("shaders/" .. name .. ".glsl")
end})

local defaultShader = kaun.newShader(shaders.defaultVert, shaders.defaultFrag)

local terrainSize = 60
local terrainHeight = 3.0
terrain.setup(terrainSize, terrainHeight, 64, 4.0, 2.0, {1.0, 0.5, 0.25}, nil, 0.4)

local waterSize = terrainSize * 5.0
local waterMesh = kaun.newPlaneMesh(waterSize, waterSize, 128, 128)
local waterShader = kaun.newShader(shaders.waterVert, shaders.waterFrag, shaders.waterGeom)
local waterState = kaun.newRenderState()
waterState:setBlendEnabled(true)
waterState:setBlendFactors("src_alpha", "one_minus_src_alpha")

local waterTrafo = kaun.newTransform()
waterTrafo:setPosition(0.0, 1.0, 0.0)

local groundMesh = kaun.newPlaneMesh(waterSize, waterSize)
local groundTrafo = kaun.newTransform()

local skyboxMesh = kaun.newBoxMesh(1, 1, 1)
local skyboxShader = kaun.newShader(shaders.skybox)
local skyboxTransform = kaun.newTransform()
local skyboxTexture = kaun.newCubeTexture("media/posx.png", "media/negx.png",
                                          "media/posy.png", "media/negy.png",
                                          "media/posz.png", "media/negz.png")
local skyboxState = kaun.newRenderState()
skyboxState:setDepthWrite(false)
skyboxState:setFrontFace("cw")

local cameraTrafo = kaun.newTransform()
cameraTrafo:lookAtPos(0, 4, terrainSize/2,  0, terrainHeight, -terrainSize/2)

local sandTexture = kaun.newTexture("media/sand.png")
sandTexture:setWrap("repeat", "repeat")

local playerRadius = 0.2
local playerMesh = kaun.newSphereMesh(playerRadius, 32, 12)
local playerTrafo = kaun.newTransform()
playerTrafo:setPosition(0, terrain.getHeight(0, 0) + playerRadius, 0)

function love.resize(w, h)
    kaun.setProjection(45, w/h, 0.1, 100.0)
    kaun.setViewport(0, 0, w, h)
end

function bool2Int(b)
    return b and 1 or 0
end

function love.update(dt)
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
        move = vec3(cameraTrafo:localDirToWorld(move.x, move.y, move.z))
        move.y = move.y + moveY -- move up down with r/f in world space
        local camPos = vec3(cameraTrafo:getPosition())
        camPos = camPos + move:normalize() * speed
        cameraTrafo:setPosition(camPos:unpack())
    end

    local playerSpeed = 1.5
    local pMove = vec3(0, 0, 0)
    pMove.x = bool2Int(lk.isDown("right")) - bool2Int(lk.isDown("left"))
    pMove.z = bool2Int(lk.isDown("up")) - bool2Int(lk.isDown("down"))
    pMove = pMove:normalize()

    if pMove:len() > 0.5 then
        local camPos = vec3(cameraTrafo:getPosition())

        local playerPos = vec3(playerTrafo:getPosition())
        playerPos = playerPos + vec3(cameraTrafo:getRight()) * pMove.x * speed
        playerPos = playerPos + vec3(cameraTrafo:getForward()) * pMove.z * speed
        playerPos.y = terrain.getHeight(playerPos.x, playerPos.z) + playerRadius
        playerTrafo:setPosition(playerPos:unpack())

        local rel = playerPos - camPos
        rel.y = 0
        local maxDist = 3.0
        if rel:len() > maxDist then
            camPos = camPos + rel:normalize() * (rel:len() - maxDist)
            cameraTrafo:setPosition(camPos:unpack())
        end
        cameraTrafo:lookAt(playerPos:unpack())
    end

    local camPos = vec3(cameraTrafo:getPosition())
    camPos.y = math.max(camPos.y, terrain.getHeight(camPos.x, camPos.z) + 0.25)
    cameraTrafo:setPosition(camPos:unpack())

    local waterPos = vec3(waterTrafo:getPosition())
    waterPos.y = waterPos.y + (bool2Int(lk.isDown("j")) - bool2Int(lk.isDown("k"))) * 0.2 * dt
    waterTrafo:setPosition(waterPos:unpack())
end

function love.mousemoved(x, y, dx, dy)
    local winW, winH = love.graphics.getDimensions()
    if love.mouse.isDown(1) then
        local dx = dx / winW
        local dy = dy / winH
        local sens = 5.0
        cameraTrafo:rotateWorld(sens * dx, 0, 1, 0)
        cameraTrafo:rotate(sens * dy, 1, 0, 0)
    end
end

function love.keypressed(key)
    if key == "space" then
        cameraTrafo:lookAt(0, 1, -terrainSize/2)
    end
end

local startTime = love.timer.getTime()

function love.draw()
    kaun.clear(0.9, 1, 1, 1)
    kaun.clearDepth()
    kaun.setViewTransform(cameraTrafo)

    local camX, camY, camZ = cameraTrafo:getPosition()
    skyboxTransform:setPosition(camX, camY - 0.04, camZ)
    kaun.setModelTransform(skyboxTransform)
    kaun.draw(skyboxMesh, skyboxShader, {
        skyboxTexture = skyboxTexture,
    }, skyboxState)
    kaun.flush()

    local terrainTexScale = 5
    kaun.setModelTransform(terrain.transform)
    kaun.draw(terrain.mesh, defaultShader, {
        color = {1, 1, 1, 1},
        ambientColor = ambientColor,
        lightDir = lightDir,
        baseTexture = sandTexture,
        texScale = 4,
    })

    kaun.setModelTransform(groundTrafo)
    kaun.draw(groundMesh, defaultShader, {
        color = {1, 1, 1, 1},
        ambientColor = ambientColor,
        lightDir = lightDir,
        baseTexture = sandTexture,
        texScale = terrainTexScale * waterSize / terrainSize,
    })

    kaun.setModelTransform(playerTrafo)
    kaun.draw(playerMesh, defaultShader, {
        color = {1, 0, 0, 1},
        ambientColor = ambientColor,
        lightDir = lightDir,
        baseTexture = sandTexture,
        texScale = 5,
    })
    kaun.flush()

    kaun.setModelTransform(waterTrafo)
    kaun.draw(waterMesh, waterShader, {
        color = {1, 1, 1, 1},
        skyboxTexture = skyboxTexture,
        ambientColor = ambientColor,
        lightDir = lightDir,
        texScale = 1,
        time = love.timer.getTime() - startTime,
    }, waterState)

    kaun.beginLoveGraphics() -- calls kaun.flush
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", 0, 0, 150, 25)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 5, 5)
    -- all draws have to finish in this block! flush batches!
    love.graphics.flushBatch()
    kaun.endLoveGraphics()
end
