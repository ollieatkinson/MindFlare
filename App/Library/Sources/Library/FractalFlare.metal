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

static float segmentGlow(float2 point, float2 start, float2 end, float width) {
	float2 line = end - start;
	float lengthSquared = max(dot(line, line), 0.00001);
	float progress = clamp(dot(point - start, line) / lengthSquared, 0.0, 1.0);
	float2 closest = start + line * progress;
	float distance = length(point - closest);
	float body = exp(-pow(distance / max(width, 0.0005), 2.0));
	return body * smoothstep(0.0, 0.08, progress) * smoothstep(1.0, 0.82, progress);
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
	float blade = pow(sin(t * M_PI_F), 0.72) * (1.0 - t * 0.58);
	float pulse = 1.0 + 0.045 * sin(phase + t * 10.0);
	float center = base.x + lean * t + curl * sin(t * M_PI_F) * (1.0 - t * 0.26);
	float lobeWidth = max(width * (0.08 + blade * (0.72 + waist * 0.22)) * pulse, 0.001);
	float edge = abs(point.x - center) / lobeWidth;
	float body = pow(smoothstep(1.02, 0.05, edge), 1.35);
	float foot = smoothstep(0.0, 0.05, t);
	float tip = smoothstep(1.0, 0.68, t);
	float innerFold = 0.58 + 0.42 * sin((point.x - center) * 36.0 + t * 18.0 + phase);
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
	float2 uv = (position - size * float2(0.5, 0.54)) / scale;
	uv.x -= (horizontalBias - 0.5) * 0.04;

	float pulse = sin(time * (0.82 + motionSeed * 0.5) + seed * M_PI_F * 2.0) * 0.5 + 0.5;
	float sway = sin(time * (0.46 + motionSeed * 0.38) + seed * M_PI_F * 2.0);
	float breath = sin(time * (0.9 + shapeSeed * 0.46) + depthWeight * M_PI_F);
	float fold = sin(time * (0.68 + foldSeed * 0.42) + inheritanceWeight * 5.2);

	float2 base = float2((horizontalBias - 0.5) * 0.05 + sway * (0.01 + connectionWeight * 0.015), 0.25);
	float height = 0.46 + depthWeight * 0.12 + nodeWeight * 0.04 + breath * 0.018;
	float width = 0.145 + branchWeight * 0.105 + leafWeight * 0.035;
	float centerLean = (horizontalBias - 0.5) * 0.08 + sway * (0.018 + connectionWeight * 0.03);

	float plate = ellipseGlow(uv, float2(base.x + centerLean * 0.2, base.y + 0.005), float2(0.16 + branchWeight * 0.07, 0.026 + connectionWeight * 0.018));
	float aura = ellipseGlow(uv, float2(base.x + centerLean * 0.08, 0.02), float2(0.23 + nodeWeight * 0.06, 0.29 + depthWeight * 0.08));

	float3 color = float3(0.0);
	color += flareHSV(primaryHue, 0.82, 1.0) * plate * (0.25 + pulse * 0.08);
	color += flareHSV(accentHue, 0.58 + metadataWeight * 0.16, 1.0) * aura * (0.045 + metadataWeight * 0.06);

	float bloom = flameLobe(
		uv,
		float2(base.x + centerLean * 0.18, base.y),
		height * (0.3 + metadataWeight * 0.1),
		width * (0.7 + branchWeight * 0.24),
		centerLean * 0.45,
		fold * 0.035,
		0.5,
		time + paletteSeed * 8.0
	);
	color += flareHSV(accentHue, 0.68, 1.0) * bloom * (0.16 + metadataWeight * 0.12);

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
		float lobeHeight = height * ((index == 0 ? 1.35 : 0.5 + a * 0.42) + depthWeight * 0.1 + inheritanceWeight * 0.06);
		float lobeWidth = width * ((index == 0 ? 0.78 : 0.3 + b * 0.34) + branchWeight * 0.12);
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
		lobe = pow(lobe, 1.16);
		float hue = mix(accentHue, primaryHue, float(index % 3) * 0.32) + (a - 0.5) * 0.12 + inheritanceWeight * 0.05;
		float opacity = index == 0 ? 0.55 : 0.17 + c * 0.18 + metadataWeight * 0.08;
		color += flareHSV(hue, 0.78 + inheritanceWeight * 0.12, 1.0) * lobe * opacity;
		color += flareHSV(coreHue + a * 0.04, 0.42 + rhythmWeight * 0.22, 1.0) * lobe * opacity * 0.32;
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
	core = pow(core, 1.08);
	color += mix(flareHSV(coreHue, 0.56 + rhythmWeight * 0.2, 1.0), float3(1.0), 0.16) * core * 0.48;

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
	color += mix(flareHSV(accentHue, 0.52, 1.0), float3(1.0), 0.3) * ridge * 0.78;

	float vignette = smoothstep(0.56, 0.18, length(uv));
	color *= vignette;
	color = color / (color + 0.95);
	return half4(half3(color), sourceColor.a);
}

[[ stitchable ]] half4 mindFlareLexiconTree(
	float2 position,
	half4 sourceColor,
	float2 size,
	float time,
	float4 profile0,
	float4 profile1,
	float4 profile2,
	float4 profile3
) {
	float seed = profile0.x;
	float paletteSeed = profile0.y;
	float shapeSeed = profile0.z;
	float motionSeed = profile0.w;
	float nodeWeight = profile1.x;
	float depthWeight = profile1.y;
	float branchWeight = profile1.z;
	float leafWeight = profile1.w;
	float inheritanceWeight = profile2.x;
	float metadataWeight = profile2.y;
	float connectionWeight = profile2.z;
	float rhythmWeight = profile2.w;
	float maxDepth = profile3.x;
	float nodeCount = profile3.y;
	float breadthSeed = profile3.z;

	float scale = max(min(size.x, size.y), 1.0);
	float2 uv = (position - size * float2(0.5, 0.54)) / scale;
	float pulse = sin(time * (0.52 + motionSeed * 0.4) + seed * M_PI_F * 2.0) * 0.5 + 0.5;
	float sway = sin(time * (0.34 + motionSeed * 0.28) + breadthSeed * M_PI_F * 2.0);
	float2 base = float2((seed - 0.5) * 0.055 + sway * 0.01, 0.27);
	float3 color = float3(0.0);

	float plate = ellipseGlow(
		uv,
		float2(base.x, base.y + 0.01),
		float2(0.18 + branchWeight * 0.12, 0.034 + connectionWeight * 0.028)
	);
	float canopy = ellipseGlow(
		uv,
		float2(base.x + sway * 0.025, -0.03 - depthWeight * 0.05),
		float2(0.22 + branchWeight * 0.18 + nodeWeight * 0.06, 0.26 + depthWeight * 0.13)
	);
	color += flareHSV(0.07 + paletteSeed * 0.1, 0.72, 1.0) * plate * (0.24 + pulse * 0.08);
	color += flareHSV(0.78 + paletteSeed * 0.18 + rhythmWeight * 0.08, 0.48 + metadataWeight * 0.18, 1.0) * canopy * (0.035 + metadataWeight * 0.055);

	float trunkHeight = 0.48 + depthWeight * 0.18 + nodeWeight * 0.05;
	float trunk = 0.0;
	for (int index = 0; index < 12; index += 1) {
		float t0 = float(index) / 12.0;
		float t1 = float(index + 1) / 12.0;
		float bend0 = sin(t0 * 4.3 + seed * 6.2 + time * 0.12) * (0.018 + connectionWeight * 0.012) + sway * t0 * 0.025;
		float bend1 = sin(t1 * 4.3 + seed * 6.2 + time * 0.12) * (0.018 + connectionWeight * 0.012) + sway * t1 * 0.025;
		float2 start = float2(base.x + bend0, base.y - trunkHeight * t0);
		float2 end = float2(base.x + bend1, base.y - trunkHeight * t1);
		float width = mix(0.015 + branchWeight * 0.01, 0.004 + inheritanceWeight * 0.006, t0);
		trunk += segmentGlow(uv, start, end, width) * (1.0 - t0 * 0.35);
	}
	color += flareHSV(0.035 + paletteSeed * 0.08, 0.8, 1.0) * trunk * 0.38;

	float levels = floor(5.0 + depthWeight * 5.0 + min(maxDepth, 18.0) * 0.05);
	float branchGlow = 0.0;
	float leafGlow = 0.0;
	for (int index = 0; index < 96; index += 1) {
		float fi = float(index);
		float level = floor(fi / 12.0);
		if (level >= levels) {
			break;
		}
		float lane = fmod(fi, 12.0);
		float slots = min(12.0, 3.0 + level * 1.55 + branchWeight * 3.0);
		if (lane >= slots) {
			continue;
		}

		float levelProgress = (level + 1.0) / (levels + 1.0);
		float laneProgress = slots <= 1.0 ? 0.0 : lane / (slots - 1.0) - 0.5;
		float branchSeed = flareHash(seed * 8.3 + fi * 1.71 + breadthSeed * 2.0);
		float branchSeedB = flareHash(shapeSeed * 9.7 + fi * 2.31 + paletteSeed);
		float spread = (0.42 + branchWeight * 0.82 + connectionWeight * 0.2) * pow(levelProgress, 0.68);
		float spineBend = sin(levelProgress * 4.3 + seed * 6.2 + time * 0.12) * (0.02 + connectionWeight * 0.014) + sway * levelProgress * 0.03;
		float2 start = float2(
			base.x + spineBend + laneProgress * 0.018 * level,
			base.y - trunkHeight * levelProgress
		);
		float angle = -M_PI_F / 2.0 +
			laneProgress * spread +
			(branchSeed - 0.5) * (0.18 + metadataWeight * 0.16) +
			sin(time * (0.22 + branchSeedB * 0.18) + branchSeed * 6.28) * 0.025;
		float length = (0.13 + nodeWeight * 0.04 + branchSeed * 0.035) * (1.0 - levelProgress * 0.44);
		float2 end = start + float2(cos(angle), sin(angle)) * length;
		float width = mix(0.008 + branchWeight * 0.006, 0.0018 + inheritanceWeight * 0.0028, levelProgress);
		float segment = segmentGlow(uv, start, end, width);
		float leaf = ellipseGlow(
			uv,
			end,
			float2(0.01 + leafWeight * 0.009 + branchSeed * 0.004, 0.01 + metadataWeight * 0.008)
		);
		branchGlow += segment * (0.5 + branchSeedB * 0.45);
		leafGlow += leaf * smoothstep(0.34, 0.96, levelProgress) * (0.06 + leafWeight * 0.12 + branchSeed * 0.04);
		float hue = 0.055 + paletteSeed * 0.12 + levelProgress * 0.12 + inheritanceWeight * 0.08 + branchSeed * 0.025;
		color += flareHSV(hue, 0.64 + metadataWeight * 0.18, 1.0) * segment * (0.18 + levelProgress * 0.22);
	}

	color += flareHSV(0.1 + paletteSeed * 0.16, 0.56 + rhythmWeight * 0.2, 1.0) * branchGlow * 0.05;
	color += mix(
		flareHSV(0.82 + paletteSeed * 0.18, 0.48 + metadataWeight * 0.26, 1.0),
		flareHSV(0.12 + rhythmWeight * 0.12, 0.7, 1.0),
		0.35 + inheritanceWeight * 0.25
	) * leafGlow;

	float density = clamp(log2(max(nodeCount, 1.0)) / 16.0, 0.0, 1.0);
	float neural = 0.0;
	for (int index = 0; index < 22; index += 1) {
		float fi = float(index);
		float a = flareHash(seed * 12.7 + fi * 2.17);
		float b = flareHash(breadthSeed * 11.3 + fi * 3.03);
		float y = base.y - trunkHeight * (0.18 + a * 0.76);
		float x = base.x + (b - 0.5) * (0.22 + branchWeight * 0.24) + sin(y * 8.0 + time * 0.15) * 0.018;
		neural += ellipseGlow(uv, float2(x, y), float2(0.004 + metadataWeight * 0.004, 0.004 + connectionWeight * 0.004)) * (0.05 + density * 0.08);
	}
	color += mix(flareHSV(0.86 + paletteSeed * 0.12, 0.45, 1.0), float3(1.0), 0.32) * neural;

	float vignette = smoothstep(0.56, 0.18, length(uv));
	color *= vignette;
	color = color / (color + 0.88);
	return half4(half3(color), sourceColor.a);
}
