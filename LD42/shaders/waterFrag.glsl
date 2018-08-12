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
