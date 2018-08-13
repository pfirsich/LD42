in vec2 texCoord;

out vec4 fragColor;

uniform sampler2D tex;

void main() {
    fragColor = texture(tex, texCoord);
    //fragColor = vec4(texCoord, 0.0, 1.0);
}
