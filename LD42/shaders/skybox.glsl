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
