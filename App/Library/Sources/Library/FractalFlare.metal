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
	float2 uv = float2(position.x / dimensions.x, 1.0 - position.y / dimensions.y);
	float2 centered = uv - float2(0.5);
	centered.y /= dimensions.x / dimensions.y;

	float countWeight = max(nodeWeight, nodeMass);
	float flameCount = floor(1.0 + clamp(synonymWeight * 2.2 + connectionWeight * 1.6 + lobeWeight * 1.2, 0.0, 4.0));
	float flowSpeed = 0.24 + motionSeed * 0.11 + connectionWeight * 0.07 + rhythmWeight * 0.05;
	float heightNoise = flareFBM(float2(time * 0.3 + seed * 8.0, shapeSeed * 12.0), foldSeed);
	float flameHeight = clamp(0.62 + heightNoise * 0.18 + depthWeight * 0.08 + countWeight * 0.08, 0.56, 0.94);
	float2 offset = float2(seed * 17.0 + paletteSeed * 6.0, -time * flowSpeed);

	float turbulence = flareFBM(centered * (0.85 + metadataWeight * 0.42) + offset, seed + foldSeed);
	float distance = max(0.08, length(centered));
	float twist = ((turbulence - 0.5) / distance) *
		smoothstep(-0.2, 0.4, uv.y) *
		(0.38 + inheritanceWeight * 0.16 + connectionWeight * 0.12);
	float2 warped = mix(centered, flareRotate(centered, twist), 0.58 + branchWeight * 0.12);

	float lean = (horizontalBias - 0.5) * 0.12 +
		sin(time * (0.48 + motionSeed * 0.25) + seed * M_PI_F * 2.0) * (0.025 + connectionWeight * 0.02);
	float centerline = lean * pow(uv.y, 0.65) +
		sin(uv.y * (4.3 + shapeSeed * 2.2) + time * (0.58 + motionSeed * 0.24) + seed * M_PI_F * 2.0) *
			(0.018 + inheritanceWeight * 0.018 + metadataWeight * 0.012) *
			smoothstep(0.06, 0.82, uv.y);
	centerline += (turbulence - 0.5) * (0.035 + metadataWeight * 0.03) * smoothstep(0.08, 0.92, uv.y);

	float normalizedY = clamp(uv.y / max(flameHeight, 0.001), 0.0, 1.0);
	float edgeNoise = flareFBM(float2(uv.y * (3.8 + shapeSeed * 2.2), time * 0.72 + foldSeed * 5.0), seed + metadataWeight);
	float baseWidth = 0.22 + countWeight * 0.055 + branchWeight * 0.035;
	float tipWidth = 0.028 + synonymWeight * 0.014 + leafWeight * 0.01;
	float width = mix(baseWidth, tipWidth, pow(normalizedY, 0.82));
	width *= 1.0 + (turbulence - 0.5) * (0.2 + inheritanceWeight * 0.12);
	width = max(width, 0.018);

	float verticalGate = smoothstep(0.0, 0.08, uv.y) * smoothstep(flameHeight, flameHeight - 0.16, uv.y);
	float silhouette = warped.x - centerline + (edgeNoise - 0.5) * width * (0.32 + metadataWeight * 0.18);
	float outerEnvelope = exp(-pow(abs(silhouette) / width, 2.05)) * verticalGate;
	float innerEnvelope = exp(-pow(abs(silhouette) / max(width * 0.38, 0.008), 2.45)) * verticalGate;
	float body = outerEnvelope;
	float flame = pow(outerEnvelope, 0.82);
	float core = pow(innerEnvelope, 1.65) * (0.72 + countWeight * 0.18);

	for (int index = 1; index < 6; index += 1) {
		float enabled = step(float(index), flameCount);
		float side = index % 2 == 0 ? -1.0 : 1.0;
		float tongueSeed = flareHash(seed * 23.0 + float(index) * 7.1 + synonymWeight * 9.0);
		float rise = smoothstep(0.12, 0.72, uv.y);
		float localHeight = flameHeight * (0.72 + tongueSeed * 0.22 + depthWeight * 0.08);
		float localGate = smoothstep(0.04, 0.14, uv.y) * smoothstep(localHeight, localHeight - 0.14, uv.y);
		float localCenter = centerline +
			side * (0.052 + synonymWeight * 0.07 + branchWeight * 0.025 + tongueSeed * 0.035) * rise +
			sin(time * (0.7 + tongueSeed * 0.45) + uv.y * 7.0 + tongueSeed * 6.28) * 0.018 * rise;
		float localWidth = width * (0.58 + tongueSeed * 0.2 + connectionWeight * 0.1);
		float tongueDistance = abs(warped.x - localCenter) / max(localWidth, 0.01);
		float tongue = exp(-pow(tongueDistance, 2.2)) * localGate;
		flame = max(flame, pow(tongue, 1.45) * enabled * (0.24 + inheritanceWeight * 0.1 + synonymWeight * 0.08));
		core = max(core, pow(tongue, 3.7) * enabled * 0.12);
	}

	float blueBase = pow(clamp(body * 0.95, 0.0, 1.0), 8.0);
	blueBase *= smoothstep(0.2, 0.0, uv.y);
	blueBase /= max(abs((warped.x - centerline) * 2.0), 0.34);
	blueBase = clamp(blueBase, 0.0, 1.0);

	float redHue = mix(0.012 + foldSeed * 0.018, accentHue, 0.035);
	float amberHue = mix(0.075 + paletteSeed * 0.025 + rhythmWeight * 0.01, primaryHue, 0.05);
	float whiteHue = mix(0.095 + shapeSeed * 0.018, coreHue, 0.05);
	float3 ember = flareHSV(redHue, 0.94, 1.0);
	float3 amber = flareHSV(amberHue, 0.86, 1.0);
	float3 white = mix(flareHSV(whiteHue, 0.22, 1.0), float3(1.0, 0.98, 0.78), 0.76);
	float3 flameColor =
		ember * pow(flame, 0.68) * 0.48 +
		amber * pow(flame, 1.08) * 0.78 +
		white * core * 0.86;
	flameColor = mix(flameColor, flareHSV(0.62, 0.72, 0.95), blueBase * 0.28);
	flameColor *= 0.94 + countWeight * 0.16 + inheritanceWeight * 0.08;

	float haloNoise = flareFBM(float2(time * 0.06 + seed, paletteSeed * 5.0), shapeSeed);
	float haloSize = 0.47 + depthWeight * 0.08 + countWeight * 0.07;
	float haloDistance = length(centered + float2(-lean * 0.18, 0.12));
	float halo = clamp(1.0 - haloDistance / haloSize, 0.0, 1.0);
	halo = pow(halo, 1.35) * (0.14 + haloNoise * 0.18 + metadataWeight * 0.06);
	float3 haloColor = flareHSV(redHue + 0.012, 0.82, 0.78) * halo;

	float grain = mix(flareHash2(position + float2(time * 23.0 + seed * 31.0, foldSeed * 19.0)), 1.0, 0.94);
	float3 color = (haloColor + flameColor) * grain;
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
