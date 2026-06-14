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
	float2 uv = (position - size * float2(0.5, 0.55)) / scale;

	float pulse = sin(time * (0.66 + motionSeed * 0.28) + seed * M_PI_F * 2.0) * 0.5 + 0.5;
	float sway = sin(time * (0.42 + motionSeed * 0.24) + seed * M_PI_F * 2.0);
	float breath = sin(time * (0.72 + shapeSeed * 0.34) + depthWeight * M_PI_F);
	float fold = sin(time * (0.52 + foldSeed * 0.28) + inheritanceWeight * 4.4);
	float lexiconLean = (horizontalBias - 0.5) * 0.07 + sway * (0.012 + connectionWeight * 0.018);

	float2 base = float2(lexiconLean * 0.18, 0.25);
	float height = 0.56 + depthWeight * 0.1 + nodeWeight * 0.035 + breath * 0.012;
	float width = 0.135 + branchWeight * 0.065 + leafWeight * 0.025;
	float warmHue = mix(0.052 + paletteSeed * 0.04 + rhythmWeight * 0.015, primaryHue, 0.1);
	float roseHue = mix(0.915 + paletteSeed * 0.035 + metadataWeight * 0.018, accentHue, 0.08);
	float violetHue = 0.71 + foldSeed * 0.065 + connectionWeight * 0.03;
	float coreHueResolved = mix(0.095 + shapeSeed * 0.035, coreHue, 0.1);
	float split = 0.72 + lobeWeight * 0.1;

	float plate = ellipseGlow(
		uv,
		float2(base.x + lexiconLean * 0.12, base.y + 0.01),
		float2(0.15 + branchWeight * 0.05, 0.024 + connectionWeight * 0.015)
	);
	float aura = ellipseGlow(
		uv,
		float2(base.x + lexiconLean * 0.2, -0.01),
		float2(0.22 + nodeWeight * 0.055, 0.31 + depthWeight * 0.075)
	);

	float3 color = float3(0.0);
	color += flareHSV(warmHue, 0.8, 1.0) * plate * (0.28 + pulse * 0.08);
	color += flareHSV(roseHue, 0.45 + metadataWeight * 0.12, 1.0) * aura * (0.055 + metadataWeight * 0.035);

	float leftOuter = flameLobe(
		uv,
		float2(base.x - width * 0.28, base.y - 0.005),
		height * (0.88 + inheritanceWeight * 0.1),
		width * (1.0 + branchWeight * 0.18),
		-0.075 + lexiconLean * 0.28,
		width * (0.25 + fold * 0.08),
		0.52,
		time * 0.32 + seed * 6.28
	);
	float rightOuter = flameLobe(
		uv,
		float2(base.x + width * 0.28, base.y - 0.01),
		height * (0.9 + depthWeight * 0.08),
		width * (0.94 + leafWeight * 0.18),
		0.105 + lexiconLean * 0.34,
		width * (-0.18 + fold * 0.06),
		0.46,
		time * 0.36 + shapeSeed * 6.28
	);
	float crown = flameLobe(
		uv,
		float2(base.x + lexiconLean * 0.08, base.y - 0.02),
		height * (1.08 + depthWeight * 0.06),
		width * (0.72 + branchWeight * 0.08),
		0.025 + lexiconLean * 0.38,
		width * (0.13 + fold * 0.1),
		0.32,
		time * 0.34 + foldSeed * 6.28
	);
	float lowerCurl = flameLobe(
		uv,
		float2(base.x + width * 0.34, base.y + 0.005),
		height * (0.45 + metadataWeight * 0.08),
		width * (0.58 + connectionWeight * 0.1),
		0.13 + lexiconLean * 0.22,
		width * (-0.42 + fold * 0.08),
		0.24,
		time * 0.5 + paletteSeed * 6.28
	);
	float innerCore = flameLobe(
		uv,
		float2(base.x + width * 0.06, base.y + 0.006),
		height * (0.62 + rhythmWeight * 0.08),
		width * (0.36 + metadataWeight * 0.06),
		0.035 + lexiconLean * 0.26,
		width * (0.06 + fold * 0.06),
		0.18,
		time * 0.42 + motionSeed * 6.28
	);

	leftOuter = pow(leftOuter, 1.04);
	rightOuter = pow(rightOuter, 1.06);
	crown = pow(crown, 1.08);
	lowerCurl = pow(lowerCurl, 1.02);
	innerCore = pow(innerCore, 0.96);
	float bodyMask = max(max(leftOuter, rightOuter), max(crown, lowerCurl));

	color += flareHSV(violetHue, 0.36 + connectionWeight * 0.08, 0.95) * leftOuter * (0.32 + inheritanceWeight * 0.08);
	color += flareHSV(roseHue, 0.7 + metadataWeight * 0.08, 1.0) * rightOuter * (0.46 + metadataWeight * 0.08);
	color += flareHSV(warmHue + 0.035, 0.7, 1.0) * crown * (0.58 + depthWeight * 0.08);
	color += flareHSV(roseHue + 0.035, 0.76, 1.0) * lowerCurl * (0.58 + connectionWeight * 0.1);
	color += mix(flareHSV(coreHueResolved, 0.5, 1.0), float3(1.0), 0.24) * innerCore * 0.72;

	float ridge = 0.0;
	for (int index = 0; index < 24; index += 1) {
		float fi = float(index);
		float a = flareHash(seed * 4.7 + fi * 1.61);
		float b = flareHash(foldSeed * 5.3 + fi * 2.71);
		float t = clamp((base.y - uv.y) / max(height * (0.72 + a * 0.26), 0.001), 0.0, 1.0);
		float side = index % 2 == 0 ? -1.0 : 1.0;
		float x = base.x +
			side * width * (0.08 + b * split * 0.48) * pow(sin(t * M_PI_F), 0.82) +
			lexiconLean * t +
			sin(t * 9.0 + time * (0.18 + a * 0.15)) * width * 0.035;
		float line = exp(-pow(abs(uv.x - x) / (0.0022 + metadataWeight * 0.002), 2.0));
		ridge += line * bodyMask * smoothstep(0.04, 0.18, t) * smoothstep(1.0, 0.7, t) * (0.035 + a * 0.045);
	}
	color += mix(flareHSV(roseHue, 0.48, 1.0), float3(1.0), 0.42) * ridge;

	float vignette = smoothstep(0.56, 0.18, length(uv));
	color *= vignette;
	color *= smoothstep(0.002, 0.045, bodyMask + plate + aura * 0.45);
	color = 1.0 - exp(-color * 1.2);
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
