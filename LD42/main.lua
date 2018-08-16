kaun = require("kaun")

cpml = require("libs.cpml")
vec3 = cpml.vec3
mat4 = cpml.mat4

local terrain = require("terrain")
local camera = require("camera")
local shaders = require("shaders")

local lightDir = {vec3(-0.8252, 0.3637, 0.4320):normalize():unpack()} -- correct!
--local lightDir = {vec3(-0.8252, 0.3237, 0.4320):normalize():unpack()} -- longer shadows!
local ambientColor = {0.15, 0.16, 0.15}

local function unpackmat4(mat, index)
    index = index or 1
    if index > 16 then return end
    return mat[index], unpackmat4(mat, index + 1)
end

local function randf(min, max)
    min = min or 1
    if max == nil then
        max = min
        min = -min
    end
    return min + love.math.random() * (max - min)
end

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

local palmAssets = {}
for i = 1, 4 do
    palmAssets[i] = {
        mesh = kaun.newObjMesh(("media/palm%d.obj"):format(i)),
        texture = kaun.newTexture(("media/palm%d.jpg"):format(i)),
    }
end
local palms = {}
for i = 1, 15 do
    local palm = kaun.newTransform()
    local x, z = terrainSize, terrainSize
    while math.sqrt(x*x + z*z) > terrainSize * 0.4 do
        x = love.math.random() * terrainSize - terrainSize/2
        z = love.math.random() * terrainSize - terrainSize/2
    end
    palm:setPosition(x, terrain.getHeight(x, z), z)
    local scale = 0.01 * (1.0 + randf(0.2)) -- palm 1
    local scale = 1.0 * (1.0 + randf(0.2))
    palm:setScale(scale, scale, scale)
    local angle = 0.15 * randf() * math.pi
    local dir = vec3(randf(-1, 1), randf(-1, 1), randf(-1, 1)):normalize()
    palm:rotate(angle, dir:unpack())
    local palmIndex = love.math.random(1, 4)
    table.insert(palms, {
        mesh = palmAssets[palmIndex].mesh,
        texture = palmAssets[palmIndex].texture,
        trafo = palm,
    })
end

local shadowMapSize = 4096
local shadowMap = kaun.newRenderTexture("depth24", shadowMapSize, shadowMapSize)
shadowMap:setBorderColor(1, 1, 1, 1)
shadowMap:setWrap("clamp_to_border", "clamp_to_border")
shadowMap:setCompareFunc("less")
local shadowCamera = kaun.newTransform()
shadowCamera:setPosition((vec3(lightDir) * 40.0):unpack())
shadowCamera:lookAt(0, 0, 0)
local shadowCamMat = mat4({shadowCamera:getMatrix()})
local lightView = -shadowCamMat
-- cpml has left, right, top, bottom (usually it's left, right, bottom, top)
local shadowProjParams = {-28, 28, 13, -10, 10.0, 80.0}
local shadowProjection = mat4.from_ortho(unpack(shadowProjParams))
local shadowMatrix = lightView * shadowProjection
local shadowMapShader = kaun.newShader(shaders.shadowMap)

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

function renderScene(shader)
    local terrainTexScale = 5
    kaun.setModelTransform(terrain.transform)
    kaun.draw(terrain.mesh, shader, {
        color = {1, 1, 1, 1},
        ambientColor = ambientColor,
        lightDir = lightDir,
        baseTexture = sandTexture,
        texScale = 4,
        shadowMap = shadowMap,
        lightTransform = {unpackmat4(shadowMatrix)},
        detailTexScale = 5.0,
        detailMapDistance = {1.0, 10.0},
    })

    kaun.setModelTransform(groundTrafo)
    kaun.draw(groundMesh, shader, {
        color = {1, 1, 1, 1},
        ambientColor = ambientColor,
        lightDir = lightDir,
        baseTexture = sandTexture,
        texScale = terrainTexScale * waterSize / terrainSize,
        shadowMap = shadowMap,
        lightTransform = {unpackmat4(shadowMatrix)},
        detailTexScale = 5.0,
        detailMapDistance = {1.0, 10.0},
    })

    for i = 1, #palms do
        kaun.setModelTransform(palms[i].trafo)
        kaun.draw(palms[i].mesh, shader, {
            color = {1, 1, 1, 1},
            ambientColor = ambientColor,
            lightDir = lightDir,
            baseTexture = palms[i].texture,
            texScale = 1,
            shadowMap = shadowMap,
            lightTransform = {unpackmat4(shadowMatrix)},
            detailTexScale = 0.0,
        })
    end
end

function love.draw()
    -- render shadow map
    kaun.setRenderTarget({}, shadowMap)
    kaun.clearDepth()

    kaun.setProjection(unpackmat4(shadowProjection))
    kaun.setViewTransform(shadowCamera)

    renderScene(shadowMapShader)

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

    renderScene(defaultShader)

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
        shadowMap = shadowMap,
        lightTransform = {unpackmat4(shadowMatrix)},
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
