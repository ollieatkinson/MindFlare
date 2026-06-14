#include <metal_stdlib>
using namespace metal;

static float flareHash(float value) {
	return fract(sin(value * 127.1) * 43758.5453);
}

static float3 flareHSV(float hue, float saturation, float value) {
	float3 rgb = clamp(abs(fract(hue + float3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	rgb = rgb * rgb * (3.0 - 2.0 * rgb);
	return value * mix(float3(1.0), rgb, saturation);
}

static float ellipseGlow(float2 point, float2 center, float2 radius) {
	float2 unit = (point - center) / max(radius, float2(0.001));
	return exp(-dot(unit, unit) * 2.4);
}

static float flameLobe(
	float2 point,
	float2 base,
	float height,
	float width,
	float lean,
	float curl,
	float waist,
	float phase
) {
	float t = clamp((base.y - point.y) / max(height, 0.001), 0.0, 1.0);
	float blade = pow(sin(t * M_PI_F), 0.62) * (1.0 - t * 0.45);
	float pulse = 1.0 + 0.08 * sin(phase + t * 10.0);
	float center = base.x + lean * t + curl * sin(t * M_PI_F) * (1.0 - t * 0.18);
	float lobeWidth = max(width * (0.12 + blade * (0.9 + waist * 0.28)) * pulse, 0.001);
	float edge = abs(point.x - center) / lobeWidth;
	float body = smoothstep(1.18, 0.08, edge);
	float foot = smoothstep(0.0, 0.05, t);
	float tip = smoothstep(1.0, 0.72, t);
	float innerFold = 0.72 + 0.28 * sin((point.x - center) * 32.0 + t * 17.0 + phase);
	return body * foot * tip * innerFold;
}

[[ stitchable ]] half4 mindFlareFractalFlame(
	float2 position,
	half4 sourceColor,
	float2 size,
	float time,
	float4 profile0,
	float4 profile1,
	float4 profile2,
	float4 profile3,
	float4 profile4
) {
	float seed = profile0.x;
	float paletteSeed = profile0.y;
	float shapeSeed = profile0.z;
	float motionSeed = profile0.w;
	float foldSeed = profile1.x;
	float horizontalBias = profile1.y;
	float nodeWeight = profile1.z;
	float depthWeight = profile1.w;
	float branchWeight = profile2.x;
	float leafWeight = profile2.y;
	float inheritanceWeight = profile2.z;
	float metadataWeight = profile2.w;
	float connectionWeight = profile3.x;
	float rhythmWeight = profile3.y;
	float primaryHue = profile3.z;
	float accentHue = profile3.w;
	float coreHue = profile4.x;
	float lobeWeight = profile4.y;

	float scale = max(min(size.x, size.y), 1.0);
	float2 uv = (position - size * float2(0.5, 0.53)) / scale;
	uv.x -= (horizontalBias - 0.5) * 0.04;

	float pulse = sin(time * (0.82 + motionSeed * 0.5) + seed * M_PI_F * 2.0) * 0.5 + 0.5;
	float sway = sin(time * (0.46 + motionSeed * 0.38) + seed * M_PI_F * 2.0);
	float breath = sin(time * (0.9 + shapeSeed * 0.46) + depthWeight * M_PI_F);
	float fold = sin(time * (0.68 + foldSeed * 0.42) + inheritanceWeight * 5.2);

	float2 base = float2((horizontalBias - 0.5) * 0.05 + sway * (0.01 + connectionWeight * 0.015), 0.25);
	float height = 0.42 + depthWeight * 0.13 + nodeWeight * 0.05 + breath * 0.02;
	float width = 0.20 + branchWeight * 0.13 + leafWeight * 0.05;
	float centerLean = (horizontalBias - 0.5) * 0.08 + sway * (0.018 + connectionWeight * 0.03);

	float plate = ellipseGlow(uv, float2(base.x + centerLean * 0.2, base.y + 0.005), float2(0.18 + branchWeight * 0.09, 0.035 + connectionWeight * 0.025));
	float aura = ellipseGlow(uv, float2(base.x + centerLean * 0.08, 0.01), float2(0.28 + nodeWeight * 0.08, 0.32 + depthWeight * 0.1));

	float3 color = float3(0.0);
	color += flareHSV(primaryHue, 0.78, 1.0) * plate * (0.42 + pulse * 0.14);
	color += flareHSV(accentHue, 0.54 + metadataWeight * 0.2, 1.0) * aura * (0.12 + metadataWeight * 0.12);

	float bloom = flameLobe(
		uv,
		float2(base.x + centerLean * 0.18, base.y),
		height * (0.34 + metadataWeight * 0.12),
		width * (0.86 + branchWeight * 0.34),
		centerLean * 0.45,
		fold * 0.035,
		0.5,
		time + paletteSeed * 8.0
	);
	color += flareHSV(accentHue, 0.58, 1.0) * bloom * (0.3 + metadataWeight * 0.2);

	float lobes = floor(4.0 + lobeWeight * 7.0 + depthWeight * 2.0);
	for (int index = 0; index < 14; index += 1) {
		if (float(index) >= lobes) {
			break;
		}
		float fi = float(index);
		float a = flareHash(seed * 9.1 + fi * 1.37 + shapeSeed);
		float b = flareHash(paletteSeed * 8.3 + fi * 2.11 + foldSeed);
		float c = flareHash(motionSeed * 7.7 + fi * 3.17 + horizontalBias);
		float sideDirection = index == 0 ? 0.0 : (index % 2 == 0 ? 1.0 : -1.0);
		float side = sideDirection * (0.14 + b * (0.3 + branchWeight * 0.28)) + (c - 0.5) * 0.14;
		float lobeHeight = height * ((index == 0 ? 1.42 : 0.52 + a * 0.48) + depthWeight * 0.12 + inheritanceWeight * 0.08);
		float lobeWidth = width * ((index == 0 ? 0.9 : 0.34 + b * 0.42) + branchWeight * 0.16);
		float phase = time * (0.36 + b * 0.52) + c * M_PI_F * 2.0;
		float lobe = flameLobe(
			uv,
			float2(base.x + width * side * 0.42, base.y - a * 0.025),
			lobeHeight * (1.0 + sin(phase) * 0.035),
			lobeWidth * (1.0 + cos(phase * 0.72 + foldSeed * M_PI_F) * 0.025),
			centerLean * (0.5 + b * 0.4) + width * ((a - 0.5) * 0.3 + side * 0.28),
			width * ((c - 0.5) * (0.32 + metadataWeight * 0.24) + fold * 0.18),
			0.22 + b * 0.28 + metadataWeight * 0.1,
			phase
		);
		float hue = primaryHue + (a - 0.5) * 0.18 + inheritanceWeight * 0.08;
		float opacity = index == 0 ? 0.72 : 0.28 + c * 0.24 + metadataWeight * 0.12;
		color += flareHSV(hue, 0.72 + inheritanceWeight * 0.16, 1.0) * lobe * opacity;
		color += flareHSV(coreHue + a * 0.05, 0.32 + rhythmWeight * 0.34, 1.0) * lobe * opacity * 0.6;
	}

	float core = flameLobe(
		uv,
		float2(base.x + centerLean * 0.08, base.y - 0.01),
		height * (0.64 + inheritanceWeight * 0.16 + depthWeight * 0.06),
		width * (0.34 + rhythmWeight * 0.16),
		centerLean * 0.42 + width * (shapeSeed - 0.5) * 0.18,
		fold * width * (0.12 + connectionWeight * 0.12),
		0.22 + metadataWeight * 0.1,
		time + foldSeed * 11.0
	);
	color += mix(flareHSV(coreHue, 0.5 + rhythmWeight * 0.24, 1.0), float3(1.0), 0.35) * core * 0.82;

	float ridge = 0.0;
	for (int index = 0; index < 18; index += 1) {
		float fi = float(index);
		float a = flareHash(seed * 4.7 + fi * 1.61);
		float b = flareHash(foldSeed * 5.3 + fi * 2.71);
		float t = clamp((base.y - uv.y) / max(height * (0.52 + a * 0.38), 0.001), 0.0, 1.0);
		float x = base.x + (b - 0.5) * width * (0.8 + branchWeight * 0.6) * (1.0 - t * 0.28) + centerLean * t + sin(t * 8.0 + time * (0.25 + a * 0.2)) * width * 0.08;
		float line = exp(-pow(abs(uv.x - x) / (0.0025 + metadataWeight * 0.003), 2.0));
		ridge += line * smoothstep(0.02, 0.18, t) * smoothstep(1.0, 0.58, t) * (0.025 + a * 0.045);
	}
	color += mix(flareHSV(accentHue, 0.45, 1.0), float3(1.0), 0.45) * ridge;

	float vignette = smoothstep(0.56, 0.18, length(uv));
	color *= vignette;
	color = color / (color + 0.72);
	return half4(half3(color), sourceColor.a);
}
