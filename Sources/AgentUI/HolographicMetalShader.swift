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
        float ignition;
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

        // The reference is a front-facing three-cell reactor, not a shaded sphere.
        // Keep the silhouette planar and let turbulent plasma provide its depth.
        float disc = smoothstep(radius + 0.015, radius - 0.025, r);
        float innerDisc = smoothstep(radius * 0.93, radius * 0.16, r);
        float spin = t * 0.17;

        // A broad, noisy corona preserves the heavy halo visible in both states.
        float outerDistance = r - radius - edgeWarp;
        float coronaArrival = smoothstep(0.34, 0.92, u.ignition);
        float chamberArrival = smoothstep(0.08, 0.62, u.ignition);
        float outerBloom = glowLine(outerDistance, 0.028, 0.28) * (0.56 + coronaArrival * 0.44);
        float outerRing = glowLine(outerDistance, 0.012, 0.52) * (0.68 + coronaArrival * 0.32);
        float hotRim = smoothstep(0.075, 0.002, abs(outerDistance)) * (0.62 + grain * 1.05);
        float brokenArc = smoothstep(0.18, 0.82, noise(float2(angle * 8.0, floor(t * 10.0) * 0.07)));
        outerRing *= 0.56 + brokenArc;

        // Three rounded triangular chambers curve around the central ignition hub.
        float cells = 0.0;
        float cellRims = 0.0;
        float seams = 0.0;
        for (int i = 0; i < 3; ++i) {
            float a = spin + float(i) * 2.0943951;
            float2 q = rotate2D(p, -a);
            float curvedEdge = q.y - (0.105 + q.x * q.x * 0.82);
            float radialMask = smoothstep(radius * 0.91, radius * 0.28, r)
                * smoothstep(radius * 0.12, radius * 0.27, r);
            float chamber = smoothstep(0.095, -0.055, curvedEdge)
                * smoothstep(-0.39, -0.09, q.y) * radialMask;
            cells = max(cells, chamber);
            cellRims += glowLine(curvedEdge, 0.012, 0.14) * radialMask;

            float2 seamEnd = float2(cos(a), sin(a)) * radius * 0.86;
            seams += glowLine(sdSegment(p, float2(0), seamEnd), 0.022, 0.24);
        }
        seams *= smoothstep(radius * 0.94, radius * 0.13, r);

        // Layered plasma makes each chamber look molten without turning it into a ball.
        float plasmaVeins = pow(fbm(rotate2D(p, -spin * 0.65) * 9.0 + t * 0.22), 2.35);
        float microPlasma = smoothstep(0.52, 0.91, fbm(p * 17.0 - t * 0.24));
        float chamberFill = disc * innerDisc * cells * (0.62 + chamberArrival * 0.38)
            * (0.22 + plasmaVeins * 0.68 + microPlasma * (0.24 + u.energy * 0.42));

        // Compact white-hot center with a three-point flare, matching the ignition frame.
        float ignitionFlash = exp(-pow((u.ignition - 0.16) * 7.5, 2.0));
        float hubCore = exp(-r * 30.0) * (1.55 + u.energy * 1.55 + ignitionFlash * 1.4);
        float hubHalo = exp(-r * 13.0) * (0.42 + u.energy * 0.7 + ignitionFlash * 0.42);
        float hubStar = glowLine(abs(sin((angle - spin) * 1.5)) * r, 0.010, 0.055)
            * smoothstep(radius * 0.38, 0.0, r);

        // Concentric mechanical arcs rotate independently around the turbine.
        float arcPattern = abs(sin(angle * 6.0 - t * 0.65));
        float innerArc = glowLine(r - radius * 0.73, 0.006, 0.034)
            * smoothstep(0.38, 0.96, arcPattern);
        float outerArc = glowLine(r - radius * 1.13, 0.005, 0.023)
            * smoothstep(0.58, 0.97, abs(sin(angle * 9.0 + t * 0.8)));

        // Short radial sparks replace the previous readable text shell.
        float sparkCell = floor((angle + M_PI_F) * 62.0);
        float sparkSeed = hash21(float2(sparkCell, floor(t * 8.0)));
        float sparkRadius = radius * (1.06 + sparkSeed * (0.48 + u.thermalShift * 0.48));
        float sparks = step(0.86 - u.energy * 0.12 - u.thermalShift * 0.09, sparkSeed)
            * glowLine(r - sparkRadius, 0.003, 0.018 + u.thermalShift * 0.018)
            * smoothstep(0.997, 1.0, abs(sin(angle * 62.0))) * (0.35 + coronaArrival * 0.65);

        float waveRadius = mix(radius * 1.08, radius * 2.3, u.shockwave);
        float shockwave = glowLine(r - waveRadius, 0.006, 0.03) * (1.0 - u.shockwave);

        float3 blue = float3(0.0, 0.58, 1.0);
        float3 orange = float3(1.0, 0.20, 0.015);
        float3 accent = mix(blue, orange, u.thermalShift);
        float3 hot = mix(float3(0.58, 0.93, 1.0), float3(1.0, 0.72, 0.13), u.thermalShift);

        float energy = outerBloom + outerRing + hotRim + cellRims + seams
            + hubCore + hubHalo + hubStar + innerArc + outerArc + sparks
            + shockwave + chamberFill;
        float aura = exp(-max(r - radius, 0.0) * 6.2)
            * smoothstep(radius * 1.72, radius * 0.74, r) * 0.16;
        float3 color = accent * (energy + aura + chamberFill * 0.62) + hot * (
            hubCore + hubHalo * 0.62 + hubStar + hotRim * 0.62
            + seams * 0.88 + cellRims * 0.58 + microPlasma * cells * disc * 0.23
        );
        color *= 0.88 + 0.18 * sin(t * 4.0 + grain * 5.0);

        float alpha = clamp(energy * 0.72 + aura + cells * disc * 0.12, 0.0, 1.0);
        return float4(color, alpha);
    }
    """#
}
#endif
