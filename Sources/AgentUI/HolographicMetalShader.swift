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

    struct VertexOutput { float4 position [[position]]; float2 uv; };

    vertex VertexOutput holographicVertex(uint vertexID [[vertex_id]]) {
        float2 positions[3] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
        VertexOutput output;
        output.position = float4(positions[vertexID], 0, 1);
        output.uv = positions[vertexID] * 0.5 + 0.5;
        return output;
    }

    float hash21(float2 p) {
        p = fract(p * float2(123.34, 456.21));
        p += dot(p, p + 45.32);
        return fract(p.x * p.y);
    }

    float noise(float2 p) {
        float2 i = floor(p), f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash21(i), hash21(i + float2(1, 0)), f.x),
                   mix(hash21(i + float2(0, 1)), hash21(i + 1.0), f.x), f.y);
    }

    float fbm(float2 p) {
        float value = 0.0, amplitude = 0.5;
        for (int i = 0; i < 6; ++i) {
            value += noise(p) * amplitude;
            p = p * 2.04 + float2(7.13, 11.71);
            amplitude *= 0.48;
        }
        return value;
    }

    float glowLine(float distance, float width, float strength) {
        return strength * width / max(abs(distance), 0.001);
    }

    float sdSegment(float2 p, float2 a, float2 b) {
        float2 pa = p - a, ba = b - a;
        float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
        return length(pa - ba * h);
    }

    float2 rotate2D(float2 p, float angle) {
        float s = sin(angle), c = cos(angle);
        return float2(c * p.x - s * p.y, s * p.x + c * p.y);
    }

    fragment float4 holographicFragment(
        VertexOutput input [[stage_in]],
        constant CoreUniforms &u [[buffer(0)]]
    ) {
        float2 p = input.uv * 2.0 - 1.0;
        p.x *= u.resolution.x / max(u.resolution.y, 1.0);
        p += float2(u.rotationY, -u.rotationX) * 0.035;

        float t = u.time;
        float radius = 0.52 + u.expansion * 0.08;
        float r = length(p);
        float angle = atan2(p.y, p.x);
        float grain = fbm(float2(angle * 4.2 - t * 0.7, r * 16.0 + t * 0.9));
        float edgeWarp = (grain - 0.5) * (0.045 + u.turbulence * 0.03);

        // The reference silhouette: a thick, broken reactor ring with a hot irregular rim.
        float outerDistance = r - radius - edgeWarp;
        float outerRing = glowLine(outerDistance, 0.012, 0.34);
        float hotRim = smoothstep(0.055, 0.002, abs(outerDistance)) * (0.55 + grain * 0.8);
        float brokenArc = smoothstep(0.18, 0.82, noise(float2(angle * 8.0, floor(t * 10.0) * 0.07)));
        outerRing *= 0.48 + brokenArc;

        // Three curved turbine blades create the unmistakable triangular core.
        float blades = 0.0;
        float bladeEdges = 0.0;
        float spin = t * 0.44;
        for (int i = 0; i < 3; ++i) {
            float a = spin + float(i) * 2.0943951;
            float2 q = rotate2D(p, -a);
            float sweep = q.y - (0.12 + q.x * q.x * 0.72);
            float radialMask = smoothstep(radius * 0.84, radius * 0.24, r);
            float angularMask = smoothstep(0.16, -0.09, sweep) * smoothstep(-0.34, -0.04, q.y);
            float blade = radialMask * angularMask;
            blades = max(blades, blade);
            bladeEdges += glowLine(sweep, 0.009, 0.11) * radialMask;
        }

        // Bright three-spoke seams and compact white-hot hub.
        float spokes = 0.0;
        for (int i = 0; i < 3; ++i) {
            float a = spin + float(i) * 2.0943951;
            float2 end = float2(cos(a), sin(a)) * radius * 0.77;
            spokes += glowLine(sdSegment(p, float2(0), end), 0.011, 0.19);
        }
        spokes *= smoothstep(radius * 0.9, radius * 0.16, r);
        float hub = exp(-r * 24.0) * (1.35 + u.energy * 1.4);

        float innerDisc = smoothstep(radius * 0.88, radius * 0.18, r);
        float plasmaVeins = pow(fbm(rotate2D(p, -spin * 0.65) * 9.0 + t * 0.22), 2.35);
        float reactorFill = innerDisc * (0.16 + plasmaVeins * 0.58 + blades * 0.22);

        // Concentric mechanical arcs rotate independently around the turbine.
        float arcPattern = abs(sin(angle * 6.0 - t * 1.1));
        float innerArc = glowLine(r - radius * 0.72, 0.005, 0.025)
            * smoothstep(0.38, 0.96, arcPattern);
        float outerArc = glowLine(r - radius * 1.12, 0.004, 0.017)
            * smoothstep(0.58, 0.97, abs(sin(angle * 9.0 + t * 0.8)));

        // Short radial sparks replace the previous readable text shell.
        float sparkCell = floor((angle + M_PI_F) * 62.0);
        float sparkSeed = hash21(float2(sparkCell, floor(t * 8.0)));
        float sparkRadius = radius * (1.05 + sparkSeed * 0.72);
        float sparks = step(0.82 - u.energy * 0.1, sparkSeed)
            * glowLine(r - sparkRadius, 0.003, 0.013)
            * smoothstep(0.997, 1.0, abs(sin(angle * 62.0)));

        float waveRadius = mix(radius * 1.08, radius * 2.3, u.shockwave);
        float shockwave = glowLine(r - waveRadius, 0.006, 0.03) * (1.0 - u.shockwave);

        float3 blue = float3(0.0, 0.58, 1.0);
        float3 orange = float3(1.0, 0.20, 0.015);
        float3 accent = mix(blue, orange, u.thermalShift);
        float3 hot = mix(float3(0.58, 0.93, 1.0), float3(1.0, 0.72, 0.13), u.thermalShift);

        float turbulentFill = blades * (0.2 + grain * 0.42 + u.energy * 0.22);
        float energy = outerRing + hotRim + bladeEdges + spokes + hub
            + innerArc + outerArc + sparks + shockwave + turbulentFill + reactorFill;
        float aura = exp(-max(r - radius, 0.0) * 7.5) * smoothstep(radius * 1.65, radius * 0.72, r) * 0.13;
        float3 color = accent * (energy + aura) + hot * (hub + hotRim * 0.52 + spokes * 0.82 + bladeEdges * 0.42);
        color *= 0.88 + 0.18 * sin(t * 4.0 + grain * 5.0);

        float alpha = clamp(energy * 0.72 + aura + blades * 0.08, 0.0, 1.0);
        return float4(color, alpha);
    }
    """#
}
#endif
