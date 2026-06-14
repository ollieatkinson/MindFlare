#include <metal_stdlib>
using namespace metal;

static float flareHash(float value) {
	return fract(sin(value * 127.1) * 43758.5453);
}

static float flareHash2(float2 value) {
	return fract(sin(dot(value, float2(12.9898, 78.233))) * 43758.5453);
}

static float3 flareHSV(float hue, float saturation, float value) {
	float3 rgb = clamp(abs(fract(hue + float3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	rgb = rgb * rgb * (3.0 - 2.0 * rgb);
	return value * mix(float3(1.0), rgb, saturation);
}

static float2 flareRotate(float2 value, float angle) {
	float sine = sin(angle);
	float cosine = cos(angle);
	return float2(
		value.x * cosine - value.y * sine,
		value.x * sine + value.y * cosine
	);
}

static float flareNoise(float2 value) {
	float2 cell = floor(value);
	float2 local = fract(value);
	float2 curve = local * local * (3.0 - 2.0 * local);
	float bottom = mix(flareHash2(cell), flareHash2(cell + float2(1.0, 0.0)), curve.x);
	float top = mix(flareHash2(cell + float2(0.0, 1.0)), flareHash2(cell + float2(1.0, 1.0)), curve.x);
	return mix(bottom, top, curve.y);
}

static float flareFBM(float2 value, float seed) {
	float result = 0.0;
	float amplitude = 0.5;
	float2 cursor = value + float2(seed * 13.17, seed * 7.31);
	for (int octave = 0; octave < 5; octave += 1) {
		result += (flareNoise(cursor) - 0.5) * amplitude;
		cursor = flareRotate(cursor * 2.03 + float2(11.7, 4.9), 0.48 + seed * 0.2);
		amplitude *= 0.5;
	}
	return result + 0.5;
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
	float synonymWeight = profile4.z;
	float nodeMass = profile4.w;

	float2 dimensions = max(size, float2(1.0));
	float2 screenUV = position / dimensions;
	float2 shaderUV = float2(screenUV.x, 1.0 - screenUV.y);
	float2 centered = shaderUV - float2(0.5);
	centered.y /= dimensions.x / dimensions.y;
	float2 centerUV = centered;

	float countWeight = max(nodeWeight, nodeMass);
	float styledNodeWeight = mix(0.64, countWeight, 0.42);
	float styledDepthWeight = mix(0.72, depthWeight, 0.42);
	float styledBranchWeight = mix(0.42, branchWeight, 0.35);
	float styledLeafWeight = mix(0.36, leafWeight, 0.28);
	float styledInheritanceWeight = mix(0.38, inheritanceWeight, 0.4);
	float styledMetadataWeight = mix(0.24, metadataWeight, 0.38);
	float styledConnectionWeight = mix(0.2, connectionWeight, 0.42);
	float styledRhythmWeight = mix(0.32, rhythmWeight, 0.32);
	float styledSynonymWeight = mix(0.08, synonymWeight, 0.7);
	float styledLobeWeight = mix(0.52, lobeWeight + synonymWeight * 0.35, 0.3);

	float flameMultiplicity = clamp(styledSynonymWeight * 0.45 + styledInheritanceWeight * 0.3 + styledLobeWeight * 0.25, 0.0, 1.0);
	float flameSpeed = 0.11 + motionSeed * 0.06 + styledConnectionWeight * 0.05 + styledSynonymWeight * 0.035;
	float heightVariation = flareFBM(float2(time * 0.28, seed * 5.1 + shapeSeed), foldSeed) *
		(0.18 + styledDepthWeight * 0.14 + countWeight * 0.04);
	float2 flowOffset = float2(seed * 8.0 + paletteSeed * 3.0, -time * flameSpeed);
	float turbulence = flareFBM(centered * (1.7 + styledBranchWeight * 0.9 + styledSynonymWeight * 0.35) + flowOffset, seed + foldSeed);
	float distance = max(0.085, length(centered));
	float twist = ((turbulence - 0.5) / distance) *
		smoothstep(-0.25, 0.42, shaderUV.y) *
		(0.18 + styledMetadataWeight * 0.09 + styledConnectionWeight * 0.07 + styledInheritanceWeight * 0.05);
	float2 warped = flareRotate(centered, twist);

	float risingNoise = flareFBM(
		float2(warped.x * (2.2 + styledLobeWeight), shaderUV.y * 2.5) + flowOffset * 0.75,
		paletteSeed + motionSeed
	);
	float lean = (horizontalBias - 0.5) * 0.1 +
		sin(time * (0.46 + motionSeed * 0.16) + seed * M_PI_F * 2.0) * (0.018 + styledConnectionWeight * 0.02);
	float centerLine = lean * smoothstep(0.08, 0.95, shaderUV.y) +
		(risingNoise - 0.5) * (0.07 + styledMetadataWeight * 0.035) * smoothstep(0.12, 0.82, shaderUV.y);
	float taper = mix(1.04, 0.34 + styledLeafWeight * 0.1, smoothstep(0.08, 0.9, shaderUV.y));
	float body = 1.12 + styledNodeWeight * 0.08 - abs(warped.x - centerLine) * (3.05 + styledBranchWeight * 0.85) / max(taper, 0.1);

	float flameHeight = 0.44 + heightVariation + styledDepthWeight * 0.05 + countWeight * 0.025;
	body *= smoothstep(0.0, 0.09, shaderUV.y);
	body *= smoothstep(flameHeight, flameHeight - 0.24, shaderUV.y);
	body += (risingNoise - 0.5) * 0.11 * smoothstep(0.12, 0.8, shaderUV.y);

	float visibleFlames = floor(1.0 + flameMultiplicity * 4.0);
	for (int index = 0; index < 4; index += 1) {
		float enabled = step(float(index) + 1.0, visibleFlames);
		float side = index % 2 == 0 ? -1.0 : 1.0;
		float tier = floor(float(index) * 0.5);
		float tongueSeed = flareHash(seed * 19.0 + float(index) * 3.7 + synonymWeight * 5.0);
		float tongueRise = smoothstep(0.18 + tier * 0.06, 0.52 + tier * 0.08, shaderUV.y);
		float tongueFade = smoothstep(flameHeight - 0.02, flameHeight - 0.23, shaderUV.y);
		float tongueCenter = centerLine +
			side * (0.035 + styledSynonymWeight * 0.055 + tier * 0.018) * tongueRise +
			sin(time * (0.38 + tongueSeed * 0.18) + tongueSeed * M_PI_F * 2.0) * 0.018 * tongueRise;
		float tongueTaper = max(taper * (0.55 - tier * 0.08), 0.1);
		float tongue = 0.72 - abs(warped.x - tongueCenter) * (5.4 + styledBranchWeight * 1.25) / tongueTaper;
		tongue *= tongueRise * tongueFade * enabled * (0.18 + styledInheritanceWeight * 0.12 + styledSynonymWeight * 0.12);
		body += max(tongue, 0.0);
	}

	float flame = smoothstep(0.02, 0.98, body);
	flame = pow(flame, 2.15 + styledLobeWeight * 0.36);
	flame /= max(smoothstep(1.04, -0.08, shaderUV.y), 0.16);
	flame = clamp(flame, 0.0, 1.0);

	float blueBase = pow(clamp(flame * 0.92, 0.0, 1.0), 13.0);
	blueBase *= smoothstep(0.22, 0.02, shaderUV.y);
	blueBase /= max(abs(warped.x - centerLine) * 5.5, 0.35);
	blueBase = clamp(blueBase, 0.0, 1.0);

	float hotCore = pow(flame, 3.1 - countWeight * 0.18) * smoothstep(0.02, 0.52, shaderUV.y);
	float emberEdge = pow(flame, 0.62) * (1.0 - hotCore * 0.38);
	float warmHue = mix(0.035 + paletteSeed * 0.04 + styledRhythmWeight * 0.012, primaryHue, 0.08);
	float redHue = mix(0.0 + foldSeed * 0.025, accentHue, 0.04);
	float coreHueResolved = mix(0.095 + shapeSeed * 0.025, coreHue, 0.06);

	float3 ember = flareHSV(redHue, 0.95, 0.95) * emberEdge;
	float3 gold = flareHSV(warmHue + 0.045, 0.8, 1.0);
	float3 whiteHot = mix(flareHSV(coreHueResolved, 0.36, 1.0), float3(1.0), 0.58);
	float intensity = 0.72 + countWeight * 0.18 + styledInheritanceWeight * 0.1 + styledSynonymWeight * 0.08;
	float3 flameColor = mix(ember, gold, smoothstep(0.0, 0.82, flame));
	flameColor = mix(flameColor, whiteHot, hotCore * 0.48);
	flameColor = mix(flareHSV(0.62 + styledConnectionWeight * 0.05, 0.75, 1.0), flameColor, 0.94 + styledLeafWeight * 0.04 * (1.0 - blueBase));
	flameColor = mix(flameColor, flareHSV(0.62, 0.72, 0.85), blueBase * 0.28);
	flameColor *= flame * intensity;

	float haloNoise = flareFBM(float2(time * 0.035 + seed, paletteSeed * 5.0), shapeSeed);
	float haloSize = 0.48 + styledDepthWeight * 0.08 + countWeight * 0.08 + styledInheritanceWeight * 0.04;
	float haloDistance = length(centerUV + float2(lean * 0.2, 0.1));
	float halo = clamp(1.0 - haloDistance / haloSize, 0.0, 1.0);
	halo = pow(halo, 1.35) * (0.2 + haloNoise * 0.2 + countWeight * 0.04 + styledSynonymWeight * 0.03);
	float3 haloColor = flareHSV(redHue + 0.015, 0.78, 0.78) * halo;

	float sparkle = mix(
		flareHash2(warped * dimensions.x + time),
		1.0,
		0.92
	);
	float3 color = (haloColor + flameColor) * sparkle;
	color = clamp(color, 0.0, 1.0);
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
