// #part /glsl/shaders/renderers/AD/integrate/vertex

#version 300 es

const vec2 vertices[] = vec2[](
    vec2(-1, -1),
    vec2( 3, -1),
    vec2(-1,  3)
);

out vec2 vPosition;
void main() {
    vec2 position = vertices[gl_VertexID];
    vPosition = position;
    gl_Position = vec4(position, 0, 1);
}

// #part /glsl/shaders/renderers/AD/integrate/fragment

#version 300 es
precision mediump float;
precision mediump sampler2D;
precision mediump sampler3D;

#define EPS 1e-5
#define FLT_MAX 3.402823e+38 

// #link /glsl/mixins/Photon
@Photon
// #link /glsl/mixins/intersectCube
@intersectCube

@constants
@random/hash/pcg
@random/hash/squashlinear
@random/distribution/uniformdivision
@random/distribution/square
@random/distribution/disk
@random/distribution/sphere
@random/distribution/exponential

@unprojectRand

uniform sampler2D uPosition;
uniform sampler2D uDirection;
uniform sampler2D uTransmittance;
uniform sampler2D uRadiance;

uniform sampler3D uVolume;
uniform sampler2D uTransferFunction;
uniform sampler2D uEnvironment;

uniform mat4 uMvpInverseMatrix;
uniform vec2 uInverseResolution;
uniform float uRandSeed;
uniform float uBlur;

uniform float uExtinction;
uniform float uMinorant;
uniform float uBoundary;
uniform float uAbsorptionBoundary;
uniform float uAnisotropy;
uniform uint uMaxBounces;
uniform uint uSteps;

in vec2 vPosition;

layout (location = 0) out vec4 oPosition;
layout (location = 1) out vec4 oDirection;
layout (location = 2) out vec4 oTransmittance;
layout (location = 3) out vec4 oRadiance;

void resetPhoton(inout uint state, inout Photon photon) {
    vec3 from, to;
    unprojectRand(state, vPosition, uMvpInverseMatrix, uInverseResolution, uBlur, from, to);
    photon.direction = normalize(to - from);
    photon.bounces = 0u;
    vec2 tbounds = max(intersectCube(from, photon.direction), 0.0);
    photon.position = from + tbounds.x * photon.direction;
    photon.transmittance = vec3(1);
}

vec4 sampleEnvironmentMap(vec3 d) {
    vec2 texCoord = vec2(atan(d.x, -d.z), asin(-d.y) * 2.0) * INVPI * 0.5 + 0.5;
    return texture(uEnvironment, texCoord);
}

vec4 sampleVolumeColor(vec3 position) {
    vec2 volumeSample = texture(uVolume, position).rg;
    vec4 transferSample = texture(uTransferFunction, volumeSample);
    return transferSample;
}

float sampleHenyeyGreensteinAngleCosine(inout uint state, float g) {
    float g2 = g * g;
    float c = (1.0 - g2) / (1.0 - g + 2.0 * g * random_uniform(state));
    return (1.0 + g2 - c * c) / (2.0 * g);
}

vec3 sampleHenyeyGreenstein(inout uint state, float g, vec3 direction) {
    // generate random direction and adjust it so that the angle is HG-sampled
    vec3 u = random_sphere(state);
    if (abs(g) < EPS) {
        return u;
    }
    float hgcos = sampleHenyeyGreensteinAngleCosine(state, g);
    vec3 circle = normalize(u - dot(u, direction) * direction);
    return sqrt(1.0 - hgcos * hgcos) * circle + hgcos * direction;
}

float max3(vec3 v) {
    return max(max(v.x, v.y), v.z);
}

float mean3(vec3 v) {
    return dot(v, vec3(1.0 / 3.0));
}

void main() {
    Photon photon;
    vec2 mappedPosition = vPosition * 0.5 + 0.5;
    photon.position = texture(uPosition, mappedPosition).xyz;
    vec4 directionAndBounces = texture(uDirection, mappedPosition);
    photon.direction = directionAndBounces.xyz;
    photon.bounces = uint(directionAndBounces.w + 0.5);
    photon.transmittance = texture(uTransmittance, mappedPosition).rgb;
    vec4 radianceAndSamples = texture(uRadiance, mappedPosition);
    photon.radiance = radianceAndSamples.rgb;
    photon.samples = uint(radianceAndSamples.w + 0.5);

    // beginning with full transmittance
    float w = 1.0;

    // control component coefficients
    float controlExtinctionCoefficient = uMinorant * uExtinction; // control extinction is fraction of actual extinction
    float controlAbsorptionCoefficient = uAbsorptionBoundary * controlExtinctionCoefficient;
    float controlScatteringCoefficient = controlExtinctionCoefficient - controlAbsorptionCoefficient;

    uint state = hash(uvec3(floatBitsToUint(mappedPosition.x), floatBitsToUint(mappedPosition.y), floatBitsToUint(uRandSeed)));
    
    int lookups = 0; 

    for (uint i = 0u; i < uSteps; i++) {
        float uMajorant = uBoundary * uExtinction;
        float dist = random_exponential(state, uMajorant);; 
        photon.position += dist * photon.direction;

        float F = 0.0;

        // control probabilities
        float PControl = controlExtinctionCoefficient / uMajorant;
        float PControlAbsorption = controlAbsorptionCoefficient / uMajorant;
        float PControlScattering = controlScatteringCoefficient / uMajorant;

        float random = random_uniform(state);        

        F += PControlAbsorption;
        
        if (any(greaterThan(photon.position, vec3(1))) || any(lessThan(photon.position, vec3(0)))) {
            // out of bounds
            vec4 envSample = sampleEnvironmentMap(photon.direction);
            vec3 radiance = photon.transmittance * envSample.rgb;
            photon.samples++;
            photon.radiance += (radiance - photon.radiance) / float(photon.samples);
            // photon.radiance = vec3(PNull, PNull, PNull);
            resetPhoton(state, photon);
        } else if (random < F) {
            // absorption
            vec3 radiance = vec3(0);
            photon.samples++;
            photon.radiance += (radiance - photon.radiance) / float(photon.samples);
            
            resetPhoton(state, photon);

            w = controlAbsorptionCoefficient / (PControlAbsorption * uMajorant);
            photon.transmittance.r *= w;
            photon.transmittance.g *= w;
            photon.transmittance.b *= w;
        } 

        F += PControlScattering; 

        if(random < F) {
            // scattering
            photon.transmittance *= vec3(controlScatteringCoefficient, controlScatteringCoefficient, controlScatteringCoefficient);
            photon.direction = sampleHenyeyGreenstein(state, uAnisotropy, photon.direction);
            photon.bounces++;
            
            w = controlScatteringCoefficient / (PControlScattering * uMajorant);
            photon.transmittance.r *= w;
            photon.transmittance.g *= w;
            photon.transmittance.b *= w;
        }

        // sample actual coefficients
        vec4 volumeSample = sampleVolumeColor(photon.position);
        float scatteringCoefficient = max3(volumeSample.rgb) * uExtinction * volumeSample.a;
        float absorptionCoefficient = (1.0 - max3(volumeSample.rgb)) * uExtinction * volumeSample.a;
        float nullCoefficient = (uBoundary - volumeSample.a) * uExtinction; // enable negative here

        // residual coefficients
        float residualAbsorptionCoefficient = absorptionCoefficient - controlAbsorptionCoefficient;
        float residualScatteringCoefficient = scatteringCoefficient - controlScatteringCoefficient;

        // residual probabilities
        float denominator = abs(residualAbsorptionCoefficient) + abs(residualScatteringCoefficient) + abs(nullCoefficient);
        float PResidualAbsorption = (1.0 - PControl) * abs(residualAbsorptionCoefficient) / denominator;
        float PResidualScattering = (1.0 - PControl) * abs(residualScatteringCoefficient) / denominator;
        float PNull = (1.0 - PControl) * abs(nullCoefficient) / denominator;

        F += PResidualAbsorption;

        if (random < F) {
            // absorption
            vec3 radiance = vec3(0);
            photon.samples++;
            photon.radiance += (radiance - photon.radiance) / float(photon.samples);
            
            resetPhoton(state, photon);

            w = residualAbsorptionCoefficient / (PResidualAbsorption * uMajorant);
            photon.transmittance.r *= w;
            photon.transmittance.g *= w;
            photon.transmittance.b *= w;
        } 
        
        // measure lookups
        lookups += 1;
        F += PResidualScattering;

        if (random < F) {
            // scattering
            photon.transmittance *= volumeSample.rgb;
            photon.direction = sampleHenyeyGreenstein(state, uAnisotropy, photon.direction);
            photon.bounces++;
            
            w = residualScatteringCoefficient / (PResidualScattering * uMajorant);
            photon.transmittance.r *= w;
            photon.transmittance.g *= w;
            photon.transmittance.b *= w;
        } else {
            // null collision
            w = nullCoefficient / (PNull * uMajorant);
            photon.transmittance.r *= w;
            photon.transmittance.g *= w;
            photon.transmittance.b *= w;
        }
    }

    oPosition = vec4(photon.position, 0);
    oDirection = vec4(photon.direction, float(photon.bounces));
    oTransmittance = vec4(photon.transmittance, 0);
    
    // photon.radiance = vec3(float(lookups) / float(photon.samples), float(lookups) / float(photon.samples), float(lookups) / float(photon.samples));
    oRadiance = vec4(photon.radiance, float(photon.samples));
}

// #part /glsl/shaders/renderers/AD/render/vertex

#version 300 es

const vec2 vertices[] = vec2[](
    vec2(-1, -1),
    vec2( 3, -1),
    vec2(-1,  3)
);

out vec2 vPosition;

void main() {
    vec2 position = vertices[gl_VertexID];
    vPosition = position * 0.5 + 0.5;
    gl_Position = vec4(position, 0, 1);
}

// #part /glsl/shaders/renderers/AD/render/fragment

#version 300 es
precision mediump float;
precision mediump sampler2D;

uniform sampler2D uColor;

in vec2 vPosition;

out vec4 oColor;

void main() {
    oColor = vec4(texture(uColor, vPosition).rgb, 1);
}

// #part /glsl/shaders/renderers/AD/reset/vertex

#version 300 es



const vec2 vertices[] = vec2[](
    vec2(-1, -1),
    vec2( 3, -1),
    vec2(-1,  3)
);

out vec2 vPosition;

void main() {
    vec2 position = vertices[gl_VertexID];
    vPosition = position;
    gl_Position = vec4(position, 0, 1);
}

// #part /glsl/shaders/renderers/AD/reset/fragment

#version 300 es
precision mediump float;

// #link /glsl/mixins/Photon
@Photon
// #link /glsl/mixins/intersectCube
@intersectCube

@constants
@random/hash/pcg
@random/hash/squashlinear
@random/distribution/uniformdivision
@random/distribution/square
@random/distribution/disk
@random/distribution/sphere
@random/distribution/exponential

@unprojectRand

uniform mat4 uMvpInverseMatrix;
uniform vec2 uInverseResolution;
uniform float uRandSeed;
uniform float uBlur;

in vec2 vPosition;

layout (location = 0) out vec4 oPosition;
layout (location = 1) out vec4 oDirection;
layout (location = 2) out vec4 oTransmittance;
layout (location = 3) out vec4 oRadiance;

void main() {
    Photon photon;
    vec3 from, to;
    uint state = hash(uvec3(floatBitsToUint(vPosition.x), floatBitsToUint(vPosition.y), floatBitsToUint(uRandSeed)));
    unprojectRand(state, vPosition, uMvpInverseMatrix, uInverseResolution, uBlur, from, to);
    photon.direction = normalize(to - from);
    vec2 tbounds = max(intersectCube(from, photon.direction), 0.0);
    photon.position = from + tbounds.x * photon.direction;
    photon.transmittance = vec3(1);
    photon.radiance = vec3(1);
    photon.bounces = 0u;
    photon.samples = 0u;
    oPosition = vec4(photon.position, 0);
    oDirection = vec4(photon.direction, float(photon.bounces));
    oTransmittance = vec4(photon.transmittance, 0);
    oRadiance = vec4(photon.radiance, float(photon.samples));
}
