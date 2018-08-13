out vec2 texCoord;

layout(location = KAUN_ATTR_POSITION) in vec2 attrPosition;

void main() {
    texCoord = attrPosition * 0.5 + 0.5;
    //texCoord.y = 1 - texCoord.y;
    gl_Position = vec4(attrPosition, 0.0, 1.0);
}
