// #part /glsl/shaders/renderers/DepthRenderer/generate/vertex

#version 300 es

uniform mat4 uMvpInverseMatrix;

layout(location = 0) in vec2 aPosition;
out vec3 vRayFrom;
out vec3 vRayTo;

// #link /glsl/mixins/unproject.glsl
@unproject

void main() {
    unproject(aPosition, uMvpInverseMatrix, vRayFrom, vRayTo);
    gl_Position = vec4(aPosition, 0, 1);
}

// #part /glsl/shaders/renderers/DepthRenderer/generate/fragment

#version 300 es
precision mediump float;

uniform mediump sampler3D uVolume;
uniform mediump sampler2D uTransferFunction;
uniform float uStepSize;
uniform float uOffset;
uniform float uExtinction;
uniform float uThreshold;

in vec3 vRayFrom;
in vec3 vRayTo;
out float oDepth;

// #link /glsl/mixins/intersectCube.glsl
@intersectCube

vec4 sampleVolumeColor(vec3 position) {
    vec2 volumeSample = texture(uVolume, position).rg;
    vec4 transferSample = texture(uTransferFunction, volumeSample);
    return transferSample;
}

void main() {
    vec3 rayDirection = vRayTo - vRayFrom;
    vec2 tbounds = max(intersectCube(vRayFrom, rayDirection), 0.0);
    if (tbounds.x >= tbounds.y) {
        oDepth = -1.0;
    } else {
        vec3 from = mix(vRayFrom, vRayTo, tbounds.x);
        vec3 to = mix(vRayFrom, vRayTo, tbounds.y);
        float rayStepLength = distance(from, to) * uStepSize;

        float t = uStepSize * uOffset;
        float accumulator = 0.0;

        while (t < 1.0 && accumulator < uThreshold) {
            vec3 position = mix(from, to, t);
            vec4 colorSample = sampleVolumeColor(position);
            accumulator += (1.0 - accumulator) * colorSample.a * rayStepLength * uExtinction;
            t += uStepSize;
        }

        if (accumulator < uThreshold) {
            oDepth = -1.0;
        } else {
            oDepth = mix(tbounds.x, tbounds.y, t);
        }
    }
}

// #part /glsl/shaders/renderers/DepthRenderer/integrate/vertex

#version 300 es

layout(location = 0) in vec2 aPosition;
out vec2 vPosition;

void main() {
    vPosition = aPosition * 0.5 + 0.5;
    gl_Position = vec4(aPosition, 0, 1);
}

// #part /glsl/shaders/renderers/DepthRenderer/integrate/fragment

#version 300 es
precision mediump float;

uniform mediump sampler2D uAccumulator;
uniform mediump sampler2D uFrame;
uniform float uMix;

in vec2 vPosition;
out vec4 oColor;

void main() {
    vec4 accumulator = texture(uAccumulator, vPosition);
    vec4 frame = texture(uFrame, vPosition);
    oColor = mix(accumulator, frame, uMix);
}

// #part /glsl/shaders/renderers/DepthRenderer/render/vertex

#version 300 es

layout(location = 0) in vec2 aPosition;
out vec2 vPosition;

void main() {
    vPosition = aPosition * 0.5 + 0.5;
    gl_Position = vec4(aPosition, 0, 1);
}

// #part /glsl/shaders/renderers/DepthRenderer/render/fragment

#version 300 es
precision mediump float;

uniform mediump sampler2D uAccumulator;

in vec2 vPosition;
out vec4 oColor;

void main() {
    float depth = texture(uAccumulator, vPosition).r;
    oColor = vec4(vec3(depth), 1);
}

// #part /glsl/shaders/renderers/DepthRenderer/reset/vertex

#version 300 es

layout(location = 0) in vec2 aPosition;

void main() {
    gl_Position = vec4(aPosition, 0, 1);
}

// #part /glsl/shaders/renderers/DepthRenderer/reset/fragment

#version 300 es
precision mediump float;

out vec4 oColor;

void main() {
    oColor = vec4(0, 0, 0, 1);
}
