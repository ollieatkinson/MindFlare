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

[[ stitchable ]] half4 mindFlareFractalCandidate(
	float2 position,
	half4 sourceColor,
	float2 size,
	float time,
	float4 profile0,
	float4 profile1,
	float4 profile2,
	float4 profile3,
	float4 profile4,
	float designIndex,
	float4 tuning0,
	float4 tuning1
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
	float intensityControl = max(tuning0.x, 0.0);
	float turbulenceControl = max(tuning0.y, 0.0);
	float structureControl = max(tuning0.z, 0.05);
	float hueControl = tuning0.w;
	float glowControl = max(tuning1.x, 0.0);

	float2 dimensions = max(size, float2(1.0));
	float2 uv = float2(position.x / dimensions.x, 1.0 - position.y / dimensions.y);
	float2 point = uv - float2(0.5);
	point.y /= dimensions.x / dimensions.y;

	int design = int(floor(designIndex + 0.5));
	float countWeight = max(nodeWeight, nodeMass);
	float energy = clamp((0.2 + countWeight * 0.26 + inheritanceWeight * 0.18 + synonymWeight * 0.14 + connectionWeight * 0.14 + lobeWeight * 0.12) * intensityControl, 0.0, 1.4);
	float tempo = time * (0.72 + motionSeed * 0.58 + rhythmWeight * 0.36);
	float lean = (horizontalBias - 0.5) * (0.16 + branchWeight * 0.08);
	float field = flareFBM(point * (1.2 + branchWeight * 1.1 + turbulenceControl * 1.2) + float2(seed * 9.0, -tempo * 0.42), seed + foldSeed);
	float hueShift = hueControl * 0.18;
	float3 ember = flareHSV(mix(0.01 + foldSeed * 0.025, accentHue, 0.04) + hueShift, 0.94, 1.0);
	float3 amber = flareHSV(mix(0.075 + paletteSeed * 0.045, primaryHue, 0.08) + hueShift, 0.82, 1.0);
	float3 hot = mix(flareHSV(mix(0.095 + shapeSeed * 0.04, coreHue, 0.08) + hueShift, 0.18, 1.0), float3(1.0, 0.98, 0.78), 0.72);
	float3 violet = flareHSV(0.76 + paletteSeed * 0.18 + rhythmWeight * 0.08 + hueShift, 0.58 + metadataWeight * 0.24, 1.0);
	float3 teal = flareHSV(0.49 + connectionWeight * 0.12 + foldSeed * 0.08 + hueShift, 0.7, 0.95);
	float3 color = float3(0.0);

	if (design == 0) {
		float height = clamp(0.58 + depthWeight * 0.16 + field * 0.12 + countWeight * 0.07, 0.52, 0.92);
		float y = clamp(uv.y / max(height, 0.001), 0.0, 1.0);
		float center = lean * pow(uv.y, 0.72) + sin(uv.y * (4.8 + shapeSeed * 2.6) + tempo + seed * 6.28) * (0.022 + metadataWeight * 0.02);
		float edge = flareFBM(float2(uv.y * 4.1, tempo * 0.75 + foldSeed), seed + paletteSeed) - 0.5;
		float width = mix(0.2 + countWeight * 0.05, 0.022 + leafWeight * 0.018, pow(y, 0.88));
		float gate = smoothstep(0.0, 0.1, uv.y) * smoothstep(height, height - 0.18, uv.y);
		float flame = exp(-pow(abs(point.x - center + edge * width * 0.36) / max(width, 0.01), 1.9)) * gate;
		float core = exp(-pow(abs(point.x - center) / max(width * 0.34, 0.006), 2.5)) * gate;
		color = ember * pow(flame, 0.7) * 0.52 + amber * pow(flame, 1.1) + hot * pow(core, 1.55);
	} else if (design == 1) {
		float radius = length(point);
		float angle = atan2(point.y, point.x);
		float pulse = sin(angle * (5.0 + branchWeight * 4.0) + radius * (18.0 + depthWeight * 8.0) - tempo * 2.1 + seed * 6.28);
		float corona = exp(-radius * (4.5 - energy)) * smoothstep(0.62, 0.04, radius);
		float filaments = pow(max(pulse * 0.5 + 0.5, 0.0), 7.0 - connectionWeight * 2.2) * corona;
		float core = exp(-radius * radius * (36.0 - countWeight * 12.0));
		color = violet * filaments * (0.8 + metadataWeight) + amber * corona * 0.24 + hot * core;
	} else if (design == 2) {
		float radius = length(point * float2(0.9, 1.16));
		float angle = atan2(point.y, point.x + lean * 0.25);
		float spiral = sin(angle * (2.4 + synonymWeight * 5.0) + radius * (26.0 + branchWeight * 11.0) - tempo * 2.4);
		float plume = smoothstep(0.0, 0.12, uv.y) * smoothstep(0.94, 0.16, uv.y) * exp(-radius * (2.4 + leafWeight));
		float arms = pow(spiral * 0.5 + 0.5, 4.0 + inheritanceWeight * 4.0) * plume;
		color = ember * plume * 0.38 + amber * arms * 1.15 + hot * pow(arms, 2.2) * 0.7;
	} else if (design == 3) {
		float ribbons = 0.0;
		for (int index = 0; index < 5; index += 1) {
			float fi = float(index);
			float ribbonSeed = flareHash(seed * 8.7 + fi * 3.1 + synonymWeight * 5.0);
			float side = fi - 2.0;
			float center = lean * uv.y + side * (0.042 + branchWeight * 0.018) * smoothstep(0.08, 0.9, uv.y);
			center += sin(uv.y * (5.5 + ribbonSeed * 4.0) + tempo * (0.8 + ribbonSeed) + ribbonSeed * 6.28) * (0.035 + metadataWeight * 0.02);
			float width = mix(0.045 + countWeight * 0.012, 0.01 + leafWeight * 0.012, uv.y);
			ribbons += exp(-pow(abs(point.x - center) / max(width, 0.005), 2.0)) * smoothstep(0.02, 0.18, uv.y) * smoothstep(0.96, 0.34, uv.y);
		}
		float glow = exp(-length(point - float2(lean * 0.18, -0.04)) * (2.4 - energy * 0.6));
		color = teal * ribbons * 0.62 + violet * pow(ribbons, 1.4) * 0.52 + amber * glow * 0.14 + hot * pow(ribbons, 3.0) * 0.34;
	} else if (design == 4) {
		float y = clamp(uv.y, 0.0, 1.0);
		float sway = sin(y * 5.2 + tempo * 1.35 + seed * 6.28) * (0.035 + connectionWeight * 0.018);
		float center = lean * pow(y, 0.65) + sway + (field - 0.5) * (0.04 + metadataWeight * 0.02);
		float height = 0.72 + depthWeight * 0.14 + countWeight * 0.05;
		float width = (0.19 + branchWeight * 0.035) * sin(clamp(y / height, 0.0, 1.0) * M_PI_F);
		width = max(width, 0.015 + leafWeight * 0.012);
		float gate = smoothstep(0.0, 0.08, y) * smoothstep(height, height - 0.16, y);
		float shell = exp(-pow(abs(point.x - center) / width, 2.15)) * gate;
		float core = exp(-pow(abs(point.x - center) / max(width * 0.42, 0.007), 2.6)) * gate;
		color = ember * shell * 0.42 + amber * pow(shell, 1.18) + hot * pow(core, 1.2);
	} else if (design == 5) {
		float crown = 0.0;
		float sparks = 0.0;
		float2 base = float2(lean * 0.25, -0.42);
		for (int index = 0; index < 14; index += 1) {
			float fi = float(index);
			float nodeSeed = flareHash(seed * 15.1 + fi * 2.41 + foldSeed);
			float angle = -M_PI_F / 2.0 + (fi / 13.0 - 0.5) * (1.9 + branchWeight * 1.2);
			angle += sin(tempo * (0.35 + nodeSeed * 0.25) + nodeSeed * 6.28) * 0.09;
			float length = 0.46 + nodeSeed * 0.24 + depthWeight * 0.12;
			float2 end = base + float2(cos(angle), sin(angle)) * length;
			crown += segmentGlow(point, base, end, 0.006 + metadataWeight * 0.004) * (0.38 + nodeSeed * 0.35);
			sparks += ellipseGlow(point, end, float2(0.012 + connectionWeight * 0.012)) * (0.28 + synonymWeight * 0.25);
		}
		float baseGlow = ellipseGlow(point, base + float2(0.0, 0.05), float2(0.22, 0.08));
		color = amber * crown + hot * sparks + ember * baseGlow * (0.42 + energy * 0.34);
	} else if (design == 6) {
		float y = clamp(uv.y, 0.0, 1.0);
		float gate = smoothstep(0.0, 0.08, y) * smoothstep(0.9 + depthWeight * 0.06, 0.32, y);
		float braidA = sin(y * (15.0 + branchWeight * 7.0) + tempo * 2.1 + seed * 6.28);
		float braidB = sin(y * (15.0 + branchWeight * 7.0) + tempo * 2.1 + seed * 6.28 + M_PI_F);
		float centerA = lean * y + braidA * (0.055 + synonymWeight * 0.025);
		float centerB = lean * y + braidB * (0.055 + connectionWeight * 0.025);
		float width = mix(0.055 + countWeight * 0.018, 0.012 + leafWeight * 0.008, y);
		float strandA = exp(-pow(abs(point.x - centerA) / width, 2.0)) * gate;
		float strandB = exp(-pow(abs(point.x - centerB) / width, 2.0)) * gate;
		float sheath = exp(-pow(abs(point.x - lean * y) / (width * 2.6), 2.0)) * gate * 0.28;
		color = ember * sheath + amber * (strandA + strandB) * 0.72 + hot * pow(max(strandA, strandB), 2.2);
	} else if (design == 7) {
		float radius = length(point * float2(1.0, 1.12));
		float angle = atan2(point.y + 0.08, point.x);
		float petals = abs(cos(angle * (3.0 + floor(branchWeight * 5.0)) + sin(tempo + radius * 6.0) * 0.35));
		float bloom = exp(-pow(radius / (0.34 + countWeight * 0.08), 2.0));
		float mask = smoothstep(0.64, 0.04, radius) * smoothstep(-0.48, -0.08, point.y);
		float petal = pow(petals, 2.4 + inheritanceWeight * 2.0) * bloom * mask;
		color = ember * bloom * 0.22 + amber * petal * 0.9 + hot * pow(petal, 2.0) * 0.76;
	} else if (design == 8) {
		float2 reactorPoint = point + float2(lean * 0.2, 0.02);
		float radius = length(reactorPoint);
		float rings = sin(radius * (42.0 + branchWeight * 18.0) - tempo * (4.0 + motionSeed * 2.0) + field * 2.4);
		float cells = flareFBM(reactorPoint * (7.0 + metadataWeight * 4.0) + float2(tempo * 0.7, -tempo * 0.45), seed + shapeSeed);
		float plasma = pow(max(rings * 0.5 + 0.5, 0.0), 3.0) * smoothstep(0.55, 0.04, radius);
		float core = exp(-radius * radius * (22.0 - countWeight * 5.0));
		color = teal * cells * plasma * 0.72 + violet * plasma * (0.44 + connectionWeight * 0.4) + hot * core;
	} else if (design == 9) {
		float roots = 0.0;
		float canopy = 0.0;
		float2 base = float2(lean * 0.2, -0.4);
		for (int index = 0; index < 16; index += 1) {
			float fi = float(index);
			float rootSeed = flareHash(seed * 12.3 + fi * 1.93 + paletteSeed);
			float side = fi / 15.0 - 0.5;
			float2 mid = base + float2(side * (0.18 + branchWeight * 0.22), 0.22 + rootSeed * 0.16);
			float2 tip = mid + float2(sin(tempo * 0.32 + rootSeed * 6.28) * 0.04, 0.18 + depthWeight * 0.08);
			roots += segmentGlow(point, base, mid, 0.008 + metadataWeight * 0.004) * 0.45;
			roots += segmentGlow(point, mid, tip, 0.005 + connectionWeight * 0.004) * 0.52;
			canopy += ellipseGlow(point, tip, float2(0.018 + synonymWeight * 0.018, 0.024 + leafWeight * 0.018)) * 0.38;
		}
		float flameHalo = ellipseGlow(point, base + float2(0.0, 0.36), float2(0.28 + countWeight * 0.08, 0.44 + depthWeight * 0.1));
		color = ember * flameHalo * 0.24 + amber * roots + hot * canopy + violet * canopy * metadataWeight * 0.42;
	} else if (design == 10) {
		float2 lensPoint = point * float2(0.86, 1.12) + float2(-lean * 0.22, 0.03);
		float radius = length(lensPoint);
		float lens = smoothstep(0.58, 0.03, radius);
		float caustic = flareFBM(lensPoint * (4.0 + structureControl * 3.0) + float2(sin(tempo) * 0.7, -tempo * 0.58), seed + shapeSeed);
		float flame = exp(-pow(abs(lensPoint.x + (caustic - 0.5) * 0.18 * turbulenceControl) / (0.18 + countWeight * 0.05), 2.0)) *
			smoothstep(-0.46, -0.16, lensPoint.y) *
			smoothstep(0.44 + depthWeight * 0.18, 0.08, lensPoint.y);
		float ring = pow(abs(sin(radius * (18.0 + structureControl * 10.0) - tempo * 2.0)), 7.0) * lens;
		color = teal * ring * 0.34 + ember * lens * 0.18 + amber * flame + hot * pow(flame, 2.2);
	} else if (design == 11) {
		float y = clamp(uv.y, 0.0, 1.0);
		float sheets = 0.0;
		float glow = 0.0;
		for (int index = 0; index < 7; index += 1) {
			float fi = float(index);
			float sheetSeed = flareHash(seed * 9.2 + fi * 1.73 + foldSeed);
			float side = fi / 6.0 - 0.5;
			float fold = side * (0.14 + branchWeight * 0.1) * sin(y * M_PI_F);
			fold += sin(y * (3.8 + sheetSeed * 5.0) + tempo * (0.55 + sheetSeed * 0.5)) * (0.035 + turbulenceControl * 0.025);
			float width = mix(0.09 + countWeight * 0.02, 0.02 + leafWeight * 0.012, y);
			float gate = smoothstep(0.02, 0.16, y) * smoothstep(0.92, 0.22, y);
			float sheet = exp(-pow(abs(point.x - lean * y - fold) / max(width, 0.008), 2.0)) * gate;
			sheets += sheet * (0.22 + sheetSeed * 0.16);
			glow += pow(sheet, 2.8) * (0.18 + sheetSeed * 0.16);
		}
		color = ember * sheets * 0.28 + violet * sheets * 0.22 + amber * pow(sheets, 1.25) * 0.72 + hot * glow;
	} else if (design == 12) {
		float radius = length(point);
		float angle = atan2(point.y, point.x + lean * 0.3);
		float fieldLines = 0.0;
		for (int index = 0; index < 9; index += 1) {
			float fi = float(index);
			float phase = fi / 9.0 * M_PI_F * 2.0 + seed * 6.28;
			float line = sin(angle * (2.0 + structureControl * 2.0) + radius * (15.0 + branchWeight * 8.0) + phase - tempo * (0.9 + fi * 0.02));
			fieldLines += pow(max(line * 0.5 + 0.5, 0.0), 12.0 - turbulenceControl * 3.0);
		}
		float hearth = exp(-pow(length(point * float2(1.2, 0.85)) / (0.22 + countWeight * 0.05), 2.0));
		float mask = smoothstep(0.62, 0.06, radius);
		color = teal * fieldLines * mask * 0.18 + amber * hearth * 0.65 + hot * pow(hearth, 2.0) + ember * mask * 0.1;
	} else if (design == 13) {
		float radius = length(point + float2(-lean * 0.2, 0.04));
		float cloud = 0.0;
		for (int octave = 0; octave < 5; octave += 1) {
			float scale = pow(1.8, float(octave));
			cloud += flareFBM(point * scale * (1.0 + structureControl * 0.4) + float2(seed * 4.0, -tempo * (0.18 + float(octave) * 0.05)), foldSeed + float(octave)) / scale;
		}
		float nebula = smoothstep(0.66, 0.04, radius) * pow(cloud, 2.0 + turbulenceControl);
		float pulse = sin(radius * (24.0 + branchWeight * 10.0) - tempo * 3.2 + field * 2.0) * 0.5 + 0.5;
		color = violet * nebula * 0.7 + teal * nebula * pulse * 0.35 + amber * pow(nebula, 2.0) * 0.5 + hot * pow(pulse * nebula, 4.0);
	} else if (design == 14) {
		float blot = flareFBM(point * (3.2 + structureControl * 2.4) + float2(seed * 5.0, -tempo * 0.32), foldSeed);
		blot += flareFBM(point * (7.0 + turbulenceControl * 3.0) - float2(tempo * 0.28, shapeSeed * 4.0), seed) * 0.45;
		float shape = smoothstep(0.62, 0.12, length(point * float2(0.9, 1.18))) * smoothstep(0.62, 0.28, blot);
		float fissure = pow(abs(sin((point.x + point.y * 0.35 + blot * 0.12) * (36.0 + structureControl * 18.0) + tempo * 2.4)), 18.0);
		float base = ellipseGlow(point, float2(lean * 0.1, -0.35), float2(0.24, 0.08));
		color = ember * shape * 0.5 + amber * fissure * shape * 0.9 + hot * pow(fissure * shape, 2.4) + teal * base * 0.18;
	} else if (design == 15) {
		float radius = length(point * float2(1.0, 1.08));
		float golden = 2.3999632;
		float spiral = 0.0;
		for (int index = 0; index < 13; index += 1) {
			float fi = float(index);
			float a = fi * golden + tempo * 0.25;
			float r = 0.045 + sqrt(fi) * (0.055 + structureControl * 0.014);
			float2 center = float2(cos(a), sin(a)) * r + float2(lean * 0.15, -0.03);
			float petal = ellipseGlow(point, center, float2(0.046 + synonymWeight * 0.018, 0.08 + depthWeight * 0.018));
			spiral += petal * (0.18 + fi * 0.012);
		}
		float flame = smoothstep(0.58, 0.02, radius) * spiral;
		color = ember * flame * 0.28 + amber * pow(flame, 1.1) + hot * pow(flame, 2.4) + violet * spiral * metadataWeight * 0.22;
	} else if (design == 16) {
		float y = clamp(uv.y, 0.0, 1.0);
		float center = lean * y * 0.5 + sin(y * 6.0 + tempo * 1.2 + seed * 6.28) * (0.018 + turbulenceControl * 0.012);
		float width = mix(0.095 + countWeight * 0.018, 0.012 + leafWeight * 0.01, pow(y, 0.75));
		float height = 0.82 + depthWeight * 0.08;
		float gate = smoothstep(0.0, 0.08, y) * smoothstep(height, height - 0.12, y);
		float flame = exp(-pow(abs(point.x - center) / width, 2.3)) * gate;
		float spectral = pow(abs(sin((point.x - center) * (36.0 + structureControl * 20.0) + y * 5.0 + tempo)), 8.0) * flame;
		color = amber * flame * 0.7 + hot * pow(flame, 2.0) + teal * spectral * 0.28 + violet * spectral * 0.22;
	} else if (design == 17) {
		float storm = 0.0;
		float nodes = 0.0;
		for (int index = 0; index < 18; index += 1) {
			float fi = float(index);
			float nodeSeed = flareHash(seed * 7.0 + fi * 4.7 + paletteSeed);
			float a = nodeSeed * M_PI_F * 2.0 + tempo * (0.18 + nodeSeed * 0.12);
			float r = 0.08 + flareHash(nodeSeed * 17.0 + fi) * (0.42 + structureControl * 0.08);
			float2 start = float2(cos(a), sin(a)) * r * 0.28;
			float2 end = float2(cos(a + 0.9 + field), sin(a + 0.9 + field)) * r;
			storm += segmentGlow(point, start, end, 0.004 + connectionWeight * 0.006) * (0.35 + metadataWeight * 0.25);
			nodes += ellipseGlow(point, end, float2(0.01 + synonymWeight * 0.012));
		}
		float core = ellipseGlow(point, float2(0.0, -0.02), float2(0.16 + countWeight * 0.04));
		color = teal * storm * 0.75 + violet * storm * 0.4 + hot * nodes + amber * core * 0.28;
	} else if (design == 18) {
		float y = clamp(uv.y, 0.0, 1.0);
		float facet = abs(point.x - lean * y) / mix(0.24 + countWeight * 0.05, 0.03, y);
		float flame = smoothstep(1.18, 0.1, facet) * smoothstep(0.0, 0.08, y) * smoothstep(0.9, 0.24, y);
		float prism = floor((atan2(point.y, point.x) + M_PI_F) / (M_PI_F * 2.0) * (5.0 + floor(structureControl * 5.0)));
		float shimmer = flareHash(prism + floor((y + tempo * 0.12) * 10.0) + seed * 8.0);
		float edge = pow(abs(1.0 - facet), 8.0) * flame;
		color = mix(ember, teal, shimmer * 0.45) * flame * 0.55 + amber * pow(flame, 1.4) + hot * edge;
	} else {
		float arches = 0.0;
		float glass = 0.0;
		for (int index = 0; index < 9; index += 1) {
			float fi = float(index);
			float lane = fi / 8.0 - 0.5;
			float archWidth = 0.06 + branchWeight * 0.025 + flareHash(fi + seed) * 0.025;
			float column = exp(-pow(abs(point.x - lane * (0.38 + structureControl * 0.08) - lean * 0.18) / archWidth, 2.0));
			float arch = exp(-pow(abs(length((point - float2(lane * 0.38 + lean * 0.18, -0.1)) * float2(1.0, 0.65)) - (0.25 + depthWeight * 0.05)) / 0.025, 2.0));
			float gate = smoothstep(-0.5, -0.16, point.y) * smoothstep(0.46, 0.04, point.y);
			arches += (column * 0.28 + arch * 0.48) * gate;
			glass += column * flareHash(fi * 3.1 + paletteSeed) * gate;
		}
		float altar = ellipseGlow(point, float2(lean * 0.1, -0.36), float2(0.32, 0.07));
		color = ember * altar * 0.36 + amber * arches * 0.62 + hot * pow(arches, 2.0) + violet * glass * 0.28 + teal * glass * connectionWeight * 0.24;
	}

	float halo = exp(-length(point + float2(-lean * 0.12, 0.08)) * (3.0 - energy * 0.8)) * (0.08 + energy * 0.16) * glowControl;
	float vignette = smoothstep(0.68, 0.18, length(point));
	float grain = mix(flareHash2(position + float2(time * 31.0, seed * 19.0)), 1.0, 0.94);
	color = (color * intensityControl + ember * halo) * vignette * grain;
	color = color / (color + 0.58);
	return half4(half3(clamp(color, 0.0, 1.0)), sourceColor.a);
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
