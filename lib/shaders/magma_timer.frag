#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform vec2 uResolution;
uniform float uProgress; // 0.0 to 1.0 (Timer progress)

out vec4 fragColor;

// Simple pseudo-random noise
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), f.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    vec2 center = vec2(0.5);
    vec2 pos = uv - center;

    // Correct aspect ratio for circle
    if (uResolution.x > uResolution.y) {
        pos.x *= uResolution.x / uResolution.y;
    } else {
        pos.y *= uResolution.y / uResolution.x;
    }

    // Polar coordinates
    float radius = length(pos);
    float angle = atan(pos.y, pos.x); // -PI to PI

    // Normalize angle to 0.0 - 1.0, starting from top (PI/2)
    float normalizedAngle = (angle + 1.570796) / 6.28318;
    if (normalizedAngle < 0.0) normalizedAngle += 1.0;

    // Ring Dimensions
    float ringWidth = 0.08;
    float ringRadius = 0.35;

    // Fire Effect
    float fireNoise = noise(vec2(angle * 4.0, radius * 10.0 - uTime * 2.0));
    float distortion = fireNoise * 0.02;

    // Mask for the ring shape
    float sdf = abs(radius - ringRadius) - ringWidth;
    float ringMask = 1.0 - smoothstep(0.0, 0.01, sdf + distortion);

    // Progress Mask (The "Timer" part)
    float progressMask = step(normalizedAngle, uProgress);

    // Magma Colors
    vec3 hotColor = vec3(1.0, 0.9, 0.2); // Yellow/White hot
    vec3 coolColor = vec3(0.8, 0.1, 0.0); // Red/Dark magma
    vec3 fireColor = mix(coolColor, hotColor, fireNoise + 0.2);

    // Background glow (subtle)
    float glow = exp(-radius * 3.0) * 0.5 * uProgress;
    vec3 glowColor = vec3(0.9, 0.4, 0.1) * glow;

    // Combine
    vec3 finalColor = fireColor * ringMask * progressMask;

    // Add inactive ring track (dim grey)
    float trackMask = (1.0 - smoothstep(0.0, 0.01, abs(radius - ringRadius) - ringWidth * 0.5));
    vec3 trackColor = vec3(0.2) * trackMask * (1.0 - progressMask);

    finalColor += trackColor + glowColor;

    fragColor = vec4(finalColor, max(ringMask * progressMask, trackMask));
}