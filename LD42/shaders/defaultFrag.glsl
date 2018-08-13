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
uniform sampler2D shadowMap;
uniform mat4 lightTransform;

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
