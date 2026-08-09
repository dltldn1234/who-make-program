#if os(macOS)
import Foundation

enum HolographicMetalShader {
    static let source = #"""
    #include <metal_stdlib>
    using namespace metal;

    struct CoreUniforms {
        float2 resolution;
        float time;
        float thermalShift;
        float energy;
        float expansion;
        float rotationX;
        float rotationY;
        float shockwave;
        float turbulence;
    };

    struct VertexOutput {
        float4 position [[position]];
        float2 uv;
    };

    vertex VertexOutput holographicVertex(uint vertexID [[vertex_id]]) {
        float2 positions[3] = {
            float2(-1.0, -1.0),
            float2(3.0, -1.0),
            float2(-1.0, 3.0)
        };
        VertexOutput output;
        output.position = float4(positions[vertexID], 0.0, 1.0);
        output.uv = positions[vertexID] * 0.5 + 0.5;
        return output;
    }

    float hash21(float2 point) {
        point = fract(point * float2(123.34, 456.21));
        point += dot(point, point + 45.32);
        return fract(point.x * point.y);
    }

    float noise(float2 point) {
        float2 cell = floor(point);
        float2 local = fract(point);
        local = local * local * (3.0 - 2.0 * local);
        return mix(
            mix(hash21(cell), hash21(cell + float2(1.0, 0.0)), local.x),
            mix(hash21(cell + float2(0.0, 1.0)), hash21(cell + 1.0), local.x),
            local.y
        );
    }

    float fbm(float2 point) {
        float value = 0.0;
        float amplitude = 0.5;
        for (int index = 0; index < 5; ++index) {
            value += noise(point) * amplitude;
            point = point * 2.03 + 17.17;
            amplitude *= 0.48;
        }
        return value;
    }

    float lineGlow(float distance, float width, float intensity) {
        return intensity / max(abs(distance) / width, 0.001);
    }

    fragment float4 holographicFragment(
        VertexOutput input [[stage_in]],
        constant CoreUniforms &uniforms [[buffer(0)]]
    ) {
        float2 uv = input.uv * 2.0 - 1.0;
        uv.x *= uniforms.resolution.x / max(uniforms.resolution.y, 1.0);
        uv += float2(uniforms.rotationY, -uniforms.rotationX) * 0.12;

        float radius = 0.48 + uniforms.expansion * 0.12;
        float distanceToCenter = length(uv);
        float angle = atan2(uv.y, uv.x);
        float time = uniforms.time;
        float pulse = sin(time * 2.4) * 0.012 + uniforms.energy * 0.035;

        float warpedRadius = distanceToCenter;
        warpedRadius += (fbm(uv * 5.0 + time * 0.18) - 0.5) * 0.055 * uniforms.turbulence;
        warpedRadius += sin(angle * 9.0 - time * 2.2) * 0.009;

        float sphere = smoothstep(radius + pulse, radius - 0.08, warpedRadius);
        float shell = lineGlow(warpedRadius - radius - pulse, 0.007, 0.008);
        float innerShell = lineGlow(warpedRadius - radius * 0.78, 0.006, 0.004);

        float longitude = abs(sin(angle * 7.0 + time * 0.65 + uniforms.rotationY * 4.0));
        float latitudeCoordinate = asin(clamp(uv.y / max(radius, 0.01), -1.0, 1.0));
        float latitude = abs(sin(latitudeCoordinate * 9.0 - time * 0.45));
        float grid = (smoothstep(0.94, 1.0, longitude) + smoothstep(0.96, 1.0, latitude)) * sphere;

        float plasma = fbm(float2(angle * 2.4 - time * 0.55, warpedRadius * 13.0 + time));
        plasma = pow(plasma, 2.2) * sphere;

        float ringA = lineGlow(length(float2(uv.x, uv.y * 3.3)) - radius * 1.26, 0.004, 0.005);
        float2 tilted = float2(uv.x * 0.58 + uv.y * 0.82, -uv.x * 0.82 + uv.y * 0.58);
        float ringB = lineGlow(length(float2(tilted.x, tilted.y * 3.8)) - radius * 1.18, 0.004, 0.004);

        float waveRadius = mix(radius * 1.1, radius * 2.25, uniforms.shockwave);
        float shockwave = lineGlow(distanceToCenter - waveRadius, 0.008, 0.009) * (1.0 - uniforms.shockwave);

        float particleCell = hash21(floor((uv + 2.0) * 95.0));
        float particleMask = step(0.985 - uniforms.energy * 0.025, particleCell);
        float particles = particleMask * smoothstep(radius * 1.9, radius * 0.55, distanceToCenter);

        float3 cold = float3(0.0, 0.68, 1.0);
        float3 hot = float3(1.0, 0.19, 0.015);
        float3 accent = mix(cold, hot, uniforms.thermalShift);
        float3 whiteHot = mix(float3(0.55, 0.94, 1.0), float3(1.0, 0.72, 0.15), uniforms.thermalShift);

        float glow = exp(-distanceToCenter * 3.6) * (0.16 + uniforms.energy * 0.34);
        float intensity = glow + shell + innerShell + grid * 0.34 + plasma * 0.72;
        intensity += ringA + ringB + shockwave + particles * 0.55;
        float core = exp(-distanceToCenter * 12.0) * (0.55 + uniforms.energy);
        float3 color = accent * intensity + whiteHot * core;
        color += accent * sphere * 0.035;

        float alpha = clamp(max(max(intensity, core), sphere * 0.08), 0.0, 1.0);
        return float4(color, alpha);
    }
    """#
}
#endif
