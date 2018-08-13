kaun = require("kaun")

cpml = require("libs.cpml")
vec3 = cpml.vec3
mat4 = cpml.mat4

local terrain = require("terrain")
local camera = require("camera")

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
local noiseTexture = kaun.newTexture("media/noise.png")
noiseTexture:setWrap("repeat", "repeat")

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

camera.lookAtPos(0, 4, terrainSize/2,  0, terrainHeight, -terrainSize/2)

local sandTexture = kaun.newTexture("media/sand.png")
sandTexture:setWrap("repeat", "repeat")

local playerRadius = 0.2
local playerMesh = kaun.newSphereMesh(playerRadius, 32, 12)
local playerTrafo = kaun.newTransform()
playerTrafo:setPosition(0, terrain.getHeight(0, 0) + playerRadius, 0)

local shadowMap = kaun.newRenderTexture("depth24", 2048, 2048)
local shadowCamera = kaun.newTransform()
shadowCamera:setPosition((vec3(lightDir) * 40.0):unpack())
shadowCamera:lookAt(0, 0, 0)
local shadowProjection = {-28, 28, -10, 13, 0.0, 100.0}

local colorTarget, depthTarget, colorTargetMS, depthTargetMS

local fullScreenQuad = kaun.newMesh("triangle_strip",
                                    kaun.newVertexFormat({"POSITION", 2, "F32"}),
                                    {{-1, -1}, { 1, -1}, {-1,  1}, { 1,  1}})
local fullScreenQuadShader = kaun.newShader(shaders.fsQuadVert, shaders.fsQuadFrag)
local fullScreenQuadState = kaun.newRenderState()
fullScreenQuadState:setDepthTest("disabled")

local depthDebugShader = kaun.newShader(shaders.fsQuadVert, shaders.depthDebug)

local testTexture = kaun.newTexture("media/test.png")

local projection = {}

function love.resize(w, h)
    projection = {45, w/h, 0.1, 100.0}
    kaun.setViewport(0, 0, w, h)
    colorTarget = kaun.newRenderTexture("rgba", w, h)
    depthTarget = kaun.newRenderTexture("depth24", w, h)
    local msaa = 8
    colorTargetMS = kaun.newRenderTexture("rgba", w, h, msaa)
    depthTargetMS = kaun.newRenderTexture("depth24", w, h, msaa)
end

function bool2Int(b)
    return b and 1 or 0
end

function love.update(dt)
    local lk = love.keyboard

    camera.update(dt)

    local playerSpeed = 2.0
    local pMove = vec3(0, 0, 0)
    pMove.x = bool2Int(lk.isDown("right")) - bool2Int(lk.isDown("left"))
    pMove.z = bool2Int(lk.isDown("up")) - bool2Int(lk.isDown("down"))
    pMove = pMove:normalize()

    if pMove:len() > 0.5 then
        local playerPos = vec3(playerTrafo:getPosition())
        playerPos = playerPos + vec3(camera.getRight()) * pMove.x * playerSpeed * dt
        playerPos = playerPos + vec3(camera.getForward()) * pMove.z * playerSpeed * dt
        playerPos.y = terrain.getHeight(playerPos.x, playerPos.z) + playerRadius
        playerTrafo:setPosition(playerPos:unpack())
        camera.updatePlayer(playerPos)
    end

    local waterPos = vec3(waterTrafo:getPosition())
    waterPos.y = waterPos.y + (bool2Int(lk.isDown("j")) - bool2Int(lk.isDown("k"))) * 0.2 * dt
    waterTrafo:setPosition(waterPos:unpack())
end

function love.mousemoved(x, y, dx, dy)
    local winW, winH = love.graphics.getDimensions()
    if love.mouse.isDown(1) then
        camera.mouseLook(dx / winW, dy / winH, 5.0)
    end
end

local startTime = love.timer.getTime()

function renderScene()
    local terrainTexScale = 5
    kaun.setModelTransform(terrain.transform)
    kaun.draw(terrain.mesh, defaultShader, {
        color = {1, 1, 1, 1},
        ambientColor = ambientColor,
        lightDir = lightDir,
        baseTexture = sandTexture,
        texScale = 4,
        shadowMap = shadowMap,
    })

    kaun.setModelTransform(groundTrafo)
    kaun.draw(groundMesh, defaultShader, {
        color = {1, 1, 1, 1},
        ambientColor = ambientColor,
        lightDir = lightDir,
        baseTexture = sandTexture,
        texScale = terrainTexScale * waterSize / terrainSize,
        shadowMap = shadowMap,
    })

    kaun.setModelTransform(playerTrafo)
    kaun.draw(playerMesh, defaultShader, {
        color = {1, 0, 0, 1},
        ambientColor = ambientColor,
        lightDir = lightDir,
        baseTexture = sandTexture,
        texScale = 5,
        shadowMap = shadowMap,
    })
end

function love.draw()
    -- render shadow map
    kaun.setRenderTarget({}, shadowMap)
    kaun.clearDepth()

    kaun.setProjection(unpack(shadowProjection))
    kaun.setViewTransform(shadowCamera)

    renderScene()

    -- render actual scene
    kaun.setRenderTarget(colorTargetMS, depthTargetMS)
    kaun.clear(0.9, 1, 1, 1)
    kaun.clearDepth()

    kaun.setProjection(unpack(projection))
    kaun.setViewTransform(camera.getTransform())

    local camX, camY, camZ = camera.getPosition()
    skyboxTransform:setPosition(camX, camY - 0.04, camZ)
    kaun.setModelTransform(skyboxTransform)
    kaun.draw(skyboxMesh, skyboxShader, {
        skyboxTexture = skyboxTexture,
    }, skyboxState)
    --kaun.flush()

    renderScene()

    -- resolve render targets
    kaun.setRenderTarget(colorTarget, depthTarget, true)

    kaun.setRenderTarget(colorTargetMS, depthTargetMS)
    kaun.setRenderTarget({}, nil, true)

    kaun.setModelTransform(waterTrafo)
    kaun.draw(waterMesh, waterShader, {
        color = {1, 1, 1, 1},
        skyboxTexture = skyboxTexture,
        depthTexture = depthTarget,
        noiseTexture = noiseTexture,
        time = love.timer.getTime() - startTime,
    }, waterState)

    -- local w, h = love.graphics.getDimensions()
    -- kaun.draw(fullScreenQuad, depthDebugShader, {
    --     depthTexture = depthTarget,
    --     range = {0.9, 1.0},
    -- }, fullScreenQuadState)

    kaun.beginLoveGraphics() -- calls kaun.flush
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", 0, 0, 150, 25)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 5, 5)
    -- all draws have to finish in this block! flush batches!
    love.graphics.flushBatch()
    kaun.endLoveGraphics()
end
