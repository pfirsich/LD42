local shaders = {}

shaders.frag = [[
in VSOUT {
    vec2 texCoord;
    vec3 normal;
    vec3 worldPos;
    vec3 eye;
} vsOut;

out vec4 fragColor;

uniform sampler2D baseTexture;
uniform vec4 color;
uniform vec3 ambientColor;
uniform vec3 lightDir; // normalized
uniform float texScale = 1.0;

void main() {
    float NdotL = max(0.0, dot(vsOut.normal, lightDir));
    vec4 tex = texture(baseTexture, vsOut.texCoord * texScale);
    vec4 detail = texture(baseTexture, vsOut.texCoord * texScale * 5.0);
    //fragColor = vec4(0.0, 0.0, 1.0, 1.0);
    //fragColor = vec4(color.rgb * NdotL, color.a);
    //fragColor = color * tex;
    vec3 col = color.rgb * mix(detail.rgb, tex.rgb, smoothstep(1.0, 10.0, length(vsOut.eye)));
    fragColor = vec4(col * (vec3(1.0) * NdotL + ambientColor), color.a);
}
]]

shaders.vert = [[
out VSOUT {
    vec2 texCoord;
    vec3 normal;
    vec3 worldPos;
    vec3 eye;
} vsOut;

layout(location = KAUN_ATTR_POSITION) in vec3 attrPosition;
layout(location = KAUN_ATTR_NORMAL) in vec3 attrNormal;
layout(location = KAUN_ATTR_TEXCOORD0) in vec2 attrTexCoord;

void main() {
    vsOut.texCoord = attrTexCoord;
    vsOut.normal = normalize(kaun_normal * attrNormal);
    vsOut.worldPos = vec3(kaun_model * vec4(attrPosition, 1.0));
    vsOut.eye = vec3(-kaun_modelView * vec4(attrPosition, 1.0));
    gl_Position = kaun_modelViewProjection * vec4(attrPosition, 1.0);
}
]]

shaders.skybox = [[
#ifdef VERTEX
out vec3 texCoords;

layout(location = KAUN_ATTR_POSITION) in vec3 attrPosition;
layout(location = KAUN_ATTR_NORMAL) in vec3 attrNormal;
layout(location = KAUN_ATTR_TEXCOORD0) in vec2 attrTexCoord;

void main() {
    texCoords = attrPosition;
    gl_Position = kaun_modelViewProjection * vec4(attrPosition, 1.0);
}
#endif

#ifdef FRAGMENT
out vec4 fragColor;

in vec3 texCoords;

uniform samplerCube skyboxTexture;

void main() {
    fragColor = texture(skyboxTexture, texCoords);
}
#endif
]]

shaders.waterVert = [[
out VSOUT {
    vec2 texCoord;
    vec3 normal;
    vec3 worldPos;
    vec3 eye;
} vsOut;

layout(location = KAUN_ATTR_POSITION) in vec3 attrPosition;
layout(location = KAUN_ATTR_NORMAL) in vec3 attrNormal;
layout(location = KAUN_ATTR_TEXCOORD0) in vec2 attrTexCoord;

uniform float time;

void main() {
    float wave = cos(attrPosition.x * attrPosition.z * 0.01 + time) * 0.04;
    wave += cos(attrPosition.x * attrPosition.z + time) * 0.02;
    //float wave = cos(attrPosition.x + time) + sin(attrPosition.z + time * 2.0) * 0.05;
    vec3 P = attrPosition;
    P.y += wave;

    vsOut.texCoord = attrTexCoord;
    vsOut.normal = normalize(kaun_normal * attrNormal);
    vsOut.worldPos = vec3(kaun_model * vec4(P, 1.0));
    vsOut.eye = vec3(-kaun_modelView * vec4(P, 1.0));
    gl_Position = kaun_modelViewProjection * vec4(P, 1.0);
}
]]

shaders.water = [[
in VSOUT {
    vec2 texCoord;
    vec3 normal;
    vec3 worldPos;
    vec3 eye;
} vsOut;

out vec4 fragColor;

uniform vec3 lightDir; // normalized
uniform float texScale = 1.0;
uniform samplerCube skyboxTexture;

const float R0 = 0.15;

void main() {
    float NdotL = max(0.0, dot(vsOut.normal, lightDir));

    vec3 worldEye = normalize(kaun_invView * vec4(vsOut.eye, 0.0)).xyz;

    vec3 reflection = texture(skyboxTexture, reflect(-worldEye, vsOut.normal)).rgb;
    vec3 refraction = texture(skyboxTexture, refract(-worldEye, vsOut.normal, R0)).rgb;
    float R = R0 + (1.0 - R0) * pow(1.0 - max(0.0, dot(worldEye, vsOut.normal)), 5);

    //fragColor = vec4(mix(refraction, reflection, R), 1.0);
    fragColor = vec4(reflection, min(1, R + 0.3));
}
]]

return shaders
