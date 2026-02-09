#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform vec2 uResolution;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;

    // Slow down the animation slightly for a more "premium" feel
    float t = uTime * 0.3;

    // --- YOUR APP THEME COLORS (Normalized 0.0 - 1.0) ---

    // Color 1: Seed Color (Forest Green: #2D6A4F)
    vec3 colorPrimary = vec3(0.176, 0.416, 0.310);

    // Color 2: Secondary Color (Warm Wheat: #E0B97F)
    vec3 colorSecondary = vec3(0.878, 0.725, 0.498);

    // Color 3: Surface Color (Warm White: #FFF9F0)
    // We use this as the base to keep it subtle
    vec3 colorSurface = vec3(1.0, 0.976, 0.941);

    // --- NOISE & MOVEMENT ---
    // Gentle, flowing waves instead of sharp noise
    float noise1 = sin(uv.x * 2.5 + t) * cos(uv.y * 1.5 - t);
    float noise2 = cos(uv.x * 3.0 - t * 0.8) * sin(uv.y * 3.5 + t);

    // Soft mixing factor
    float mixFactor = smoothstep(-1.2, 1.2, noise1 + noise2);

    // --- COLOR MIXING ---
    // 1. Mix the Primary (Green) and Secondary (Wheat) first
    vec3 accentMix = mix(colorPrimary,colorSurface, mixFactor);

    // 2. Mix the Result with the Surface (White)
    // heavily favoring the white (0.6 to 0.9 range) to create that "subtle opacity" look
    // This prevents the green/wheat from being too heavy or dark.
    float whiteMask = 0.7 + 0.2 * sin(t + uv.y * 3.0);

    vec3 finalColor = mix(accentMix, colorSurface, whiteMask);

    // Add a very slight grain/dither to prevent color banding on mobile screens
    float grain = fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
    finalColor += grain * 0.02;

    fragColor = vec4(finalColor, 1.0);
}