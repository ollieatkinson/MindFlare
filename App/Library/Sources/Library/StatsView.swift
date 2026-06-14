//
// github.com/screensailor 2022
//

import SwiftUI
import Lexicon

struct StatsButton: View {

	let id: UInt

	@Environment(\.events) var events

	@State var my: Editor.Object?

	var body: some View {
		Button {
			app.menu.view.stats >> events
		} label: {
			Label("Stats", systemImage: "flame")
		}
		.help("Show Stats (⌘ L)")
		.on(app.document[id].editor.show.stats) { _ in
			guard my == nil else {
				my = nil
				return
			}
			my = Editor.Object.instance(id: id)
		}
		.popover(item: $my) { my in
			StatsView().environmentObject(my)
		}
	}
}

struct StatsView: View {

	@EnvironmentObject var my: Editor.Object

	@State var name = "..."
	@State var count = (nodes: "", synonyms: "", types: "")
	@State private var visualization = StatsVisualization.flame

	var body: some View {
		VStack(alignment: .center) {
			Group {
				switch visualization {
					case .flame:
						FractalFlareView(graph: my.snapshot.graph)
					case .tree:
						LexiconTreeFlareView(graph: my.snapshot.graph)
				}
			}
			.frame(width: 256, height: 256)
			Picker("Visualization", selection: $visualization) {
				Label("Flame", systemImage: "flame")
					.tag(StatsVisualization.flame)
				Label("Tree", systemImage: "point.3.connected.trianglepath.dotted")
					.tag(StatsVisualization.tree)
			}
			.labelsHidden()
			.pickerStyle(.segmented)
			.frame(width: 160)
			Text("MindFlare")
				.font(.title)
			Divider()
			HStack {
				Spacer()
				VStack(alignment: .leading) {
					Text("Lexicon \t\t\(name)")
					Text("Nodes \t\t\(count.nodes)")
					Text("Synonyms \t\(count.synonyms)")
					Text("Inheritance \t\(count.types)")
				}.fixedSize()
				Spacer()
			}
			Divider()
			Text(my.snapshot.graph.date.formatted(date: .long, time: .shortened))
				.font(.caption)
		}
		.padding()
		.task {

			self.name = my.snapshot.graph.root.name

			var count = (nodes: 0, synonyms: 0, types: 0)

			my.snapshot.graph.root.traverse(name: "o") { id, name, node in
				count.nodes += 1
				count.synonyms += node.protonym == nil ? 0 : 1
				count.types += node.type.count
			}

			self.count = ("\(count.nodes)", "\(count.synonyms)", "\(count.types)")
		}
	}
}

private enum StatsVisualization: String, Hashable {
	case flame
	case tree
}

struct FractalFlareView: View {

	private let profile: Profile

	init(graph: Lexicon.Graph) {
		self.profile = Profile(graph)
	}

	var body: some View {
		TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
			Canvas(rendersAsynchronously: true) { context, size in
				Self.draw(
					profile: profile,
					in: &context,
					size: size,
					time: timeline.date.timeIntervalSinceReferenceDate
				)
			}
		}
		.aspectRatio(1, contentMode: .fit)
		.background {
			Circle()
				.fill(.black.opacity(0.92))
				.overlay {
					Circle()
						.stroke(.black, lineWidth: 2)
				}
		}
		.clipShape(Circle())
		.accessibilityLabel("Animated fractal flame shaped by the Lexicon")
	}

	nonisolated private static func draw(
		profile: Profile,
		in context: inout GraphicsContext,
		size: CGSize,
		time: TimeInterval
	) {
		let scale = min(size.width, size.height)
		let center = CGPoint(
			x: size.width * (0.49 + profile.horizontalBias * 0.04),
			y: size.height * 0.53
		)
		let pulse = CGFloat(
			sin(time * (0.82 + Double(profile.motionSeed) * 0.5) + Double(profile.seed) * Double.pi * 2)
		) * 0.5 + 0.5

		drawLogoGlow(
			in: &context,
			profile: profile,
			center: center,
			scale: scale,
			pulse: pulse
		)
		drawMorphingFlame(
			in: &context,
			profile: profile,
			center: center,
			scale: scale,
			time: time
		)
	}

	nonisolated private static func drawLogoGlow(
		in context: inout GraphicsContext,
		profile: Profile,
		center: CGPoint,
		scale: CGFloat,
		pulse: CGFloat
	) {
		let plate = Path(ellipseIn: CGRect(
			x: center.x - scale * (0.18 + profile.branchWeight * 0.09),
			y: center.y + scale * 0.22,
			width: scale * (0.36 + profile.branchWeight * 0.18 + profile.leafWeight * 0.06),
			height: scale * (0.07 + profile.connectionWeight * 0.05 + profile.metadataWeight * 0.03)
		))
		context.fill(
			plate,
			with: .radialGradient(
				Gradient(colors: [
					Color(hue: hue(profile.primaryHue), saturation: 0.82, brightness: 1).opacity(0.5 + Double(pulse) * 0.14),
					Color(hue: hue(profile.coreHue), saturation: 0.78, brightness: 0.92).opacity(0.14 + Double(profile.connectionWeight) * 0.08),
					.clear,
				]),
				center: CGPoint(x: center.x, y: center.y + scale * 0.26),
				startRadius: 0,
				endRadius: scale * 0.27
			)
		)

		let aura = Path(ellipseIn: CGRect(
			x: center.x - scale * (0.3 + profile.nodeWeight * 0.04),
			y: center.y - scale * (0.18 + profile.depthWeight * 0.04),
			width: scale * (0.6 + profile.nodeWeight * 0.1),
			height: scale * (0.58 + profile.depthWeight * 0.12)
		))
		context.fill(
			aura,
			with: .radialGradient(
				Gradient(colors: [
					Color(hue: hue(profile.accentHue), saturation: 0.5 + Double(profile.metadataWeight) * 0.24, brightness: 1).opacity(0.16 + Double(profile.metadataWeight) * 0.12),
					Color(hue: hue(profile.primaryHue + profile.inheritanceWeight * 0.08), saturation: 0.72, brightness: 1).opacity(0.1 + Double(pulse) * 0.06),
					.clear,
				]),
				center: CGPoint(
					x: center.x + scale * (profile.horizontalBias - 0.5) * 0.08,
					y: center.y + scale * 0.08
				),
				startRadius: 0,
				endRadius: scale * 0.36
			)
		)
	}

	nonisolated private static func drawMorphingFlame(
		in context: inout GraphicsContext,
		profile: Profile,
		center: CGPoint,
		scale: CGFloat,
		time: TimeInterval
	) {
		let base = CGPoint(x: center.x, y: center.y + scale * 0.25)
		let sway = CGFloat(sin(time * (0.46 + Double(profile.motionSeed) * 0.38) + Double(profile.seed) * Double.pi * 2))
		let breath = CGFloat(sin(time * (0.9 + Double(profile.shapeSeed) * 0.46) + Double(profile.depthWeight) * Double.pi))
		let fold = CGFloat(sin(time * (0.68 + Double(profile.foldSeed) * 0.42) + Double(profile.inheritanceWeight) * 5.2))
		let height = scale * (0.42 + profile.depthWeight * 0.13 + profile.nodeWeight * 0.05 + breath * 0.02)
		let width = scale * (0.2 + profile.branchWeight * 0.13 + profile.leafWeight * 0.05)
		let centerLean = (profile.horizontalBias - 0.5) * scale * 0.08 + sway * scale * (0.018 + profile.connectionWeight * 0.03)

		let bloom = lowerBloomPath(
			center: CGPoint(
				x: base.x + centerLean * 0.35,
				y: base.y - height * 0.16
			),
			width: width * (0.86 + profile.branchWeight * 0.34),
			height: height * (0.22 + profile.metadataWeight * 0.14),
			lean: centerLean * 0.8
		)
		drawSoftLobe(
			in: &context,
			path: bloom,
			base: CGPoint(x: base.x, y: base.y),
			tip: CGPoint(x: base.x + centerLean, y: base.y - height * 0.34),
			colors: [
				Color(hue: hue(profile.accentHue), saturation: 0.58, brightness: 1).opacity(0.22 + Double(profile.metadataWeight) * 0.14),
				Color(hue: hue(profile.primaryHue), saturation: 0.82, brightness: 1).opacity(0.36 + Double(profile.inheritanceWeight) * 0.1),
				Color(hue: hue(profile.coreHue), saturation: 0.62, brightness: 1).opacity(0.2),
			],
			blur: scale * 0.004
		)

		for lobe in profile.lobes {
			let phase = time * (0.36 + Double(lobe.motion) * 0.52) + Double(lobe.phase) * Double.pi * 2
			let lobeWave = CGFloat(sin(phase))
			let lobeFold = CGFloat(cos(phase * 0.72 + Double(profile.foldSeed) * Double.pi))
			let lobeBase = CGPoint(
				x: base.x + width * lobe.side * 0.42,
				y: base.y - height * lobe.baseLift
			)
			let lobeHeight = height * lobe.height * (1 + lobeWave * 0.035)
			let lobeWidth = width * lobe.width * (1 + lobeFold * 0.025)
			let lobeLean = centerLean * (0.5 + lobe.motion * 0.4) + width * (lobe.lean + lobe.side * 0.28) + sway * scale * 0.006
			let lobeCurl = width * (lobe.curl + fold * 0.18 + lobeFold * 0.08)
			let path = flamePath(
				base: lobeBase,
				height: lobeHeight,
				width: lobeWidth,
				lean: lobeLean,
				curl: lobeCurl,
				waist: lobe.waist
			)
			drawSoftLobe(
				in: &context,
				path: path,
				base: lobeBase,
				tip: CGPoint(x: lobeBase.x + lobeLean + lobeCurl, y: lobeBase.y - lobeHeight),
				colors: flameColors(profile: profile, lobe: lobe),
				blur: scale * lobe.blur
			)
		}

		let core = flamePath(
			base: CGPoint(x: base.x + centerLean * 0.08, y: base.y - scale * 0.01),
			height: height * (0.64 + profile.inheritanceWeight * 0.16 + profile.depthWeight * 0.06),
			width: width * (0.34 + profile.rhythmWeight * 0.16),
			lean: centerLean * 0.42 + width * (profile.shapeSeed - 0.5) * 0.18,
			curl: fold * width * (0.12 + profile.connectionWeight * 0.12),
			waist: 0.22 + profile.metadataWeight * 0.1
		)
		drawSoftLobe(
			in: &context,
			path: core,
			base: CGPoint(x: base.x, y: base.y),
			tip: CGPoint(x: base.x + centerLean * 0.32, y: base.y - height * 0.68),
			colors: [
				Color.white.opacity(0.5 + Double(profile.metadataWeight) * 0.14),
				Color(hue: hue(profile.coreHue), saturation: 0.48 + Double(profile.rhythmWeight) * 0.24, brightness: 1).opacity(0.72),
				Color(hue: hue(profile.accentHue), saturation: 0.54, brightness: 1).opacity(0.42),
			],
			blur: 0
		)

		drawFlameFolds(
			in: &context,
			base: base,
			height: height,
			width: width,
			sway: sway,
			fold: fold + centerLean / max(width, 1),
			profile: profile,
			time: time
		)
	}

	nonisolated private static func drawSoftLobe(
		in context: inout GraphicsContext,
		path: Path,
		base: CGPoint,
		tip: CGPoint,
		colors: [Color],
		blur: CGFloat
	) {
		if blur > 0 {
			context.drawLayer { layer in
				layer.addFilter(.blur(radius: blur))
				layer.fill(
					path,
					with: .linearGradient(
						Gradient(colors: colors),
						startPoint: base,
						endPoint: tip
					)
				)
			}
		}
		context.fill(
			path,
			with: .linearGradient(
				Gradient(colors: colors),
				startPoint: base,
				endPoint: tip
			)
		)
	}

	nonisolated private static func flameColors(profile: Profile, lobe: Lobe) -> [Color] {
		let warmth = profile.primaryHue + lobe.hueShift
		let accent = profile.accentHue + lobe.hueShift * 0.7
		let core = profile.coreHue + lobe.seed * 0.05
		return [
			Color(hue: hue(accent), saturation: 0.44 + Double(lobe.metadata) * 0.28, brightness: 1).opacity(Double(lobe.opacity) * 0.62),
			Color(hue: hue(warmth), saturation: 0.72 + Double(profile.inheritanceWeight) * 0.16, brightness: 1).opacity(Double(lobe.opacity)),
			Color(hue: hue(core), saturation: 0.32 + Double(profile.rhythmWeight) * 0.34, brightness: 1).opacity(Double(lobe.opacity) * 0.78),
			Color.white.opacity(Double(lobe.opacity) * (0.14 + lobe.childWeight * 0.16)),
		]
	}

	nonisolated private static func flamePath(
		base: CGPoint,
		height: CGFloat,
		width: CGFloat,
		lean: CGFloat,
		curl: CGFloat,
		waist: CGFloat
	) -> Path {
		let tip = CGPoint(x: base.x + lean + curl, y: base.y - height)
		var path = Path()
		path.move(to: CGPoint(x: base.x, y: base.y))
		path.addCurve(
			to: tip,
			control1: CGPoint(
				x: base.x - width * (0.72 - waist * 0.18),
				y: base.y - height * (0.24 + waist * 0.08)
			),
			control2: CGPoint(
				x: tip.x - width * (0.22 + waist * 0.18) - curl * 0.5,
				y: tip.y + height * (0.26 + waist * 0.2)
			)
		)
		path.addCurve(
			to: CGPoint(x: base.x, y: base.y),
			control1: CGPoint(
				x: tip.x + width * (0.38 + waist * 0.24) + curl * 0.3,
				y: tip.y + height * (0.2 + waist * 0.16)
			),
			control2: CGPoint(
				x: base.x + width * (0.62 - waist * 0.12),
				y: base.y - height * (0.16 + waist * 0.08)
			)
		)
		return path
	}

	nonisolated private static func lowerBloomPath(
		center: CGPoint,
		width: CGFloat,
		height: CGFloat,
		lean: CGFloat
	) -> Path {
		var path = Path()
		path.move(to: CGPoint(x: center.x - width * 0.45, y: center.y + height * 0.08))
		path.addCurve(
			to: CGPoint(x: center.x + width * 0.06 + lean, y: center.y - height * 0.58),
			control1: CGPoint(x: center.x - width * 0.54, y: center.y - height * 0.28),
			control2: CGPoint(x: center.x - width * 0.18 + lean * 0.4, y: center.y - height * 0.6)
		)
		path.addCurve(
			to: CGPoint(x: center.x + width * 0.48, y: center.y + height * 0.16),
			control1: CGPoint(x: center.x + width * 0.34 + lean * 0.3, y: center.y - height * 0.42),
			control2: CGPoint(x: center.x + width * 0.6, y: center.y - height * 0.08)
		)
		path.addCurve(
			to: CGPoint(x: center.x - width * 0.45, y: center.y + height * 0.08),
			control1: CGPoint(x: center.x + width * 0.24, y: center.y + height * 0.48),
			control2: CGPoint(x: center.x - width * 0.34, y: center.y + height * 0.42)
		)
		return path
	}

	nonisolated private static func drawFlameFolds(
		in context: inout GraphicsContext,
		base: CGPoint,
		height: CGFloat,
		width: CGFloat,
		sway: CGFloat,
		fold: CGFloat,
		profile: Profile,
		time: TimeInterval
	) {
		let foldCount = max(9, min(30, 9 + profile.maxDepth + Int(profile.branchWeight * 8) + Int(profile.connectionWeight * 6)))
		for index in 0..<foldCount {
			let progress = CGFloat(index) / CGFloat(max(foldCount - 1, 1))
			let signature = profile.signatures[index % profile.signatures.count]
			let seed = signature.seed
			let side = (signature.secondarySeed - 0.5) * (0.7 + profile.branchWeight * 0.7) + (progress - 0.5) * 0.3
			let baseOffset = side * width * (0.18 + signature.childWeight * 0.14)
			let topOffset = sin(seed * .pi * 2 + CGFloat(time) * (0.28 + signature.tertiarySeed * 0.3)) *
				width * (0.16 + signature.metadata * 0.14) +
				sway * width * 0.12
			let top = CGPoint(
				x: base.x + topOffset + fold * width * 0.08,
				y: base.y - height * (0.5 + signature.depth * 0.34 + seed * 0.12)
			)
			var ridge = Path()
			ridge.move(to: CGPoint(x: base.x + baseOffset, y: base.y - height * 0.02))
			ridge.addCurve(
				to: top,
				control1: CGPoint(
					x: base.x + side * width * (0.44 + signature.childWeight * 0.28),
					y: base.y - height * (0.18 + signature.depth * 0.12)
				),
				control2: CGPoint(
					x: base.x + topOffset - side * width * (0.18 + signature.inheritance * 0.16),
					y: base.y - height * (0.38 + signature.depth * 0.18)
				)
			)
			let warmth = profile.primaryHue + seed * 0.08 + profile.metadataWeight * 0.05
			context.stroke(
				ridge,
				with: .linearGradient(
					Gradient(colors: [
						Color(hue: hue(warmth), saturation: 0.62, brightness: 1).opacity(0.06 + Double(signature.metadata) * 0.08),
						Color.white.opacity(0.14 + Double(seed) * 0.13),
						Color(hue: hue(profile.accentHue), saturation: 0.42, brightness: 1).opacity(0.04 + Double(signature.inheritance) * 0.06),
					]),
					startPoint: CGPoint(x: base.x, y: base.y),
					endPoint: top
				),
				style: StrokeStyle(
					lineWidth: max(0.45, width * (0.006 + profile.inheritanceWeight * 0.004)),
					lineCap: .round,
					lineJoin: .round
				)
			)
		}
	}

	private struct Signature {
		var seed: CGFloat
		var secondarySeed: CGFloat
		var tertiarySeed: CGFloat
		var depth: CGFloat
		var childWeight: CGFloat
		var inheritance: CGFloat
		var metadata: CGFloat
	}

	private struct Lobe {
		var seed: CGFloat
		var side: CGFloat
		var baseLift: CGFloat
		var height: CGFloat
		var width: CGFloat
		var lean: CGFloat
		var curl: CGFloat
		var waist: CGFloat
		var hueShift: CGFloat
		var opacity: CGFloat
		var blur: CGFloat
		var motion: CGFloat
		var phase: CGFloat
		var metadata: CGFloat
		var childWeight: CGFloat
	}

	private struct Profile {
		var nodeCount = 0
		var inheritanceCount = 0
		var connectionCount = 0
		var metadataCount = 0
		var leafCount = 0
		var maxBreadth = 0
		var maxDepth = 1
		var totalDepth = 0
		var characterCount = 0
		var vowelCount = 0
		var seed: CGFloat = 0
		var paletteSeed: CGFloat = 0
		var shapeSeed: CGFloat = 0
		var motionSeed: CGFloat = 0
		var foldSeed: CGFloat = 0
		var horizontalBias: CGFloat = 0
		var signatures: [Signature] = []
		var lobes: [Lobe] = []

		init(_ graph: Lexicon.Graph) {
			var hasher = FlareHasher()
			var sampled: [(priority: UInt64, signature: Signature)] = []
			hasher.mix("mindflare-fractal-flame-v2")
			hasher.mix(graph.root.name)

			graph.root.traverse { id, _, node in
				let depth = id.reduce(1) { depth, character in
					character == "." ? depth + 1 : depth
				}
				let childCount = node.children.count
				let inheritance = node.type.count + (node.protonym == nil ? 0 : 1)
				let metadata = node.notes.count + node.comments.count + (node.defaultValue == nil ? 0 : 1)
				var nodeHasher = FlareHasher()
				nodeHasher.mix(id)
				nodeHasher.mix(node.name)
				nodeHasher.mix(depth)
				nodeHasher.mix(childCount)
				nodeHasher.mix(inheritance)
				nodeHasher.mix(metadata)
				for type in node.type.sorted() {
					nodeHasher.mix(type)
				}
				if let protonym = node.protonym {
					nodeHasher.mix(protonym)
				}
				for connection in node.connections.map(\.reference).sorted() {
					nodeHasher.mix(connection)
				}
				for note in node.notes {
					nodeHasher.mix(note)
				}
				for comment in node.comments {
					nodeHasher.mix(comment)
				}
				if let defaultValue = node.defaultValue {
					nodeHasher.mix(String(describing: defaultValue))
				}
				let nodeHash = nodeHasher.finalized()
				hasher.mix(nodeHash)

				nodeCount += 1
				inheritanceCount += inheritance
				connectionCount += node.connections.count
				metadataCount += metadata
				leafCount += childCount == 0 ? 1 : 0
				maxBreadth = max(maxBreadth, childCount)
				maxDepth = max(maxDepth, depth)
				totalDepth += depth
				characterCount += node.name.unicodeScalars.count
				vowelCount += node.name.unicodeScalars.reduce(0) { total, scalar in
					"aeiouAEIOU".unicodeScalars.contains(scalar) ? total + 1 : total
				}

				let signature = Signature(
					seed: Self.unit(nodeHash),
					secondarySeed: Self.unit(nodeHash, shift: 16),
					tertiarySeed: Self.unit(nodeHash, shift: 32),
					depth: min(CGFloat(depth) / 18, 1),
					childWeight: Self.logWeight(childCount, ceiling: 48),
					inheritance: min(CGFloat(inheritance) / 4, 1),
					metadata: min(CGFloat(metadata) / 4, 1)
				)
				let priority = Self.scramble(nodeHash &+ UInt64(nodeCount))
				if sampled.count < 96 {
					sampled.append((priority, signature))
				} else if let index = sampled.indices.max(by: { sampled[$0].priority < sampled[$1].priority }) {
					if priority < sampled[index].priority {
						sampled[index] = (priority, signature)
					}
				}
			}

			let fingerprint = hasher.finalized()
			seed = Self.unit(fingerprint)
			paletteSeed = Self.unit(Self.scramble(fingerprint &+ 1))
			shapeSeed = Self.unit(Self.scramble(fingerprint &+ 2))
			motionSeed = Self.unit(Self.scramble(fingerprint &+ 3))
			foldSeed = Self.unit(Self.scramble(fingerprint &+ 4))
			horizontalBias = Self.unit(Self.scramble(fingerprint &+ 5))
			signatures = sampled
				.sorted { lhs, rhs in lhs.priority < rhs.priority }
				.map(\.signature)
			if signatures.isEmpty {
				signatures = [
					Signature(
						seed: seed,
						secondarySeed: shapeSeed,
						tertiarySeed: paletteSeed,
						depth: 0.2,
						childWeight: 0.2,
						inheritance: 0,
						metadata: 0
					)
				]
			}
			lobes = Self.makeLobes(
				signatures: signatures,
				fingerprint: fingerprint,
				depthWeight: depthWeight,
				branchWeight: branchWeight,
				inheritanceWeight: inheritanceWeight,
				metadataWeight: metadataWeight
			)
		}

		var nodeWeight: CGFloat {
			Self.logWeight(nodeCount, ceiling: 50_000)
		}

		var inheritanceWeight: CGFloat {
			ratio(inheritanceCount, to: nodeCount)
		}

		var connectionWeight: CGFloat {
			min(ratio(connectionCount, to: nodeCount) * 4, 1)
		}

		var metadataWeight: CGFloat {
			min(ratio(metadataCount, to: nodeCount) * 3, 1)
		}

		var depthWeight: CGFloat {
			Self.logWeight(maxDepth, ceiling: 32)
		}

		var branchWeight: CGFloat {
			Self.logWeight(maxBreadth, ceiling: 96)
		}

		var leafWeight: CGFloat {
			ratio(leafCount, to: nodeCount)
		}

		var rhythmWeight: CGFloat {
			ratio(vowelCount, to: characterCount)
		}

		var primaryHue: CGFloat {
			0.015 + paletteSeed * 0.115
		}

		var accentHue: CGFloat {
			0.82 + paletteSeed * 0.28 + rhythmWeight * 0.12
		}

		var coreHue: CGFloat {
			0.075 + shapeSeed * 0.09
		}

		private func ratio(_ value: Int, to total: Int) -> CGFloat {
			guard total > 0 else {
				return 0
			}
			return min(CGFloat(value) / CGFloat(total), 1)
		}

		private static func makeLobes(
			signatures: [Signature],
			fingerprint: UInt64,
			depthWeight: CGFloat,
			branchWeight: CGFloat,
			inheritanceWeight: CGFloat,
			metadataWeight: CGFloat
		) -> [Lobe] {
			let count = 4 + Int(unit(scramble(fingerprint &+ 6)) * 5) + Int(depthWeight * 2)
			return (0..<count).map { index in
				let signature = signatures[index % signatures.count]
				let sideDirection: CGFloat = index == 0 ? 0 : index.isMultiple(of: 2) ? 1 : -1
				let sideMagnitude = index == 0 ? 0 : 0.14 + signature.secondarySeed * (0.3 + branchWeight * 0.28)
				let heightBoost: CGFloat = index == 0 ? 0.42 : signature.depth * 0.3
				return Lobe(
					seed: signature.seed,
					side: sideDirection * sideMagnitude + (signature.tertiarySeed - 0.5) * 0.14,
					baseLift: index == 0 ? 0 : signature.childWeight * 0.08,
					height: (index == 0 ? 0.98 : 0.44 + signature.seed * 0.38) + heightBoost + inheritanceWeight * 0.08,
					width: (index == 0 ? 0.9 : 0.34 + signature.secondarySeed * 0.42) + branchWeight * 0.16,
					lean: (signature.seed - 0.5) * 0.3,
					curl: (signature.tertiarySeed - 0.5) * (0.32 + metadataWeight * 0.24),
					waist: 0.22 + signature.childWeight * 0.28 + metadataWeight * 0.1,
					hueShift: (signature.seed - 0.5) * 0.18 + signature.inheritance * 0.08,
					opacity: index == 0 ? 0.76 : 0.28 + signature.tertiarySeed * 0.24 + signature.metadata * 0.12,
					blur: index == 0 ? 0.006 : 0.002 + signature.seed * 0.004,
					motion: 0.3 + signature.secondarySeed * 0.7,
					phase: signature.tertiarySeed,
					metadata: signature.metadata,
					childWeight: signature.childWeight
				)
			}
		}

		private static func logWeight(_ value: Int, ceiling: CGFloat) -> CGFloat {
			guard value > 0 else {
				return 0
			}
			return min(log1p(CGFloat(value)) / log1p(ceiling), 1)
		}

		private static func unit(_ value: UInt64, shift: Int = 0) -> CGFloat {
			CGFloat(Double((value >> shift) & 0xffff) / Double(UInt16.max))
		}

		private static func scramble(_ value: UInt64) -> UInt64 {
			var result = value &+ 0x9e37_79b9_7f4a_7c15
			result = (result ^ (result >> 30)) &* 0xbf58_476d_1ce4_e5b9
			result = (result ^ (result >> 27)) &* 0x94d0_49bb_1331_11eb
			return result ^ (result >> 31)
		}
	}

	private struct FlareHasher {
		private var value: UInt64 = 0xcbf2_9ce4_8422_2325

		mutating func mix(_ string: String) {
			for byte in string.utf8 {
				mix(byte)
			}
			mix(0xff)
		}

		mutating func mix(_ integer: Int) {
			mix(UInt64(bitPattern: Int64(integer)))
		}

		mutating func mix(_ integer: UInt64) {
			var value = integer
			for _ in 0..<8 {
				mix(UInt8(truncatingIfNeeded: value))
				value >>= 8
			}
		}

		mutating func finalized() -> UInt64 {
			value
		}

		private mutating func mix(_ byte: UInt8) {
			value ^= UInt64(byte)
			value &*= 0x0000_0100_0000_01b3
		}
	}

	nonisolated private static func hue(_ value: CGFloat) -> Double {
		let remainder = value.truncatingRemainder(dividingBy: 1)
		return Double(remainder >= 0 ? remainder : remainder + 1)
	}
}

struct LexiconTreeFlareView: View {

	let graph: Lexicon.Graph

	var body: some View {
		TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
			Canvas(rendersAsynchronously: true) { context, size in
				Self.draw(
					graph: graph,
					in: &context,
					size: size,
					time: timeline.date.timeIntervalSinceReferenceDate
				)
			}
		}
		.aspectRatio(1, contentMode: .fit)
		.background {
			Circle()
				.fill(.black.opacity(0.92))
				.overlay {
					Circle()
						.stroke(.black, lineWidth: 2)
				}
		}
		.clipShape(Circle())
		.accessibilityLabel("Animated Lexicon tree flare")
	}

	nonisolated private static func draw(
		graph: Lexicon.Graph,
		in context: inout GraphicsContext,
		size: CGSize,
		time: TimeInterval
	) {
		let profile = Profile(graph)
		let scale = min(size.width, size.height)
		let center = CGPoint(x: size.width * 0.5, y: size.height * 0.52)
		let drift = CGFloat(sin(time * 0.42 + profile.seed * .pi * 2)) * 0.08

		let glow = Path(ellipseIn: CGRect(
			x: center.x - scale * (0.15 + profile.nodeWeight * 0.12),
			y: center.y + scale * 0.16,
			width: scale * (0.3 + profile.nodeWeight * 0.24),
			height: scale * (0.12 + profile.inheritanceWeight * 0.12)
		))
		context.fill(
			glow,
			with: .radialGradient(
				Gradient(colors: [
					Color(hue: 0.02 + profile.seed * 0.04, saturation: 0.76, brightness: 1).opacity(0.48),
					Color(hue: 0.12 + profile.inheritanceWeight * 0.12, saturation: 0.62, brightness: 1).opacity(0.16),
					.clear,
				]),
				center: CGPoint(x: center.x, y: center.y + scale * 0.24),
				startRadius: 0,
				endRadius: scale * 0.32
			)
		)

		var budget = 720
		drawNode(
			in: &context,
			node: graph.root,
			origin: CGPoint(x: center.x, y: center.y + scale * 0.24),
			length: scale * (0.22 + profile.depthWeight * 0.08),
			angle: -.pi / 2 + drift,
			depth: 0,
			maxDepth: max(5, min(12, profile.maxDepth + 3)),
			time: time,
			seed: profile.seed,
			budget: &budget
		)
	}

	nonisolated private static func drawNode(
		in context: inout GraphicsContext,
		node: Lexicon.Graph.Node,
		origin: CGPoint,
		length: CGFloat,
		angle: CGFloat,
		depth: Int,
		maxDepth: Int,
		time: TimeInterval,
		seed: CGFloat,
		budget: inout Int
	) {
		guard budget > 0, depth < maxDepth, length > 1 else {
			return
		}
		budget -= 1

		let end = CGPoint(
			x: origin.x + cos(angle) * length,
			y: origin.y + sin(angle) * length
		)
		var path = Path()
		path.move(to: origin)
		path.addQuadCurve(
			to: end,
			control: CGPoint(
				x: (origin.x + end.x) * 0.5 + cos(angle + .pi / 2) * length * 0.12,
				y: (origin.y + end.y) * 0.5 + sin(angle + .pi / 2) * length * 0.12
			)
		)

		let progress = Double(depth) / Double(maxDepth)
		let inherited = node.protonym == nil ? 0.0 : 1.0
		let typed = min(Double(node.type.count) * 0.18, 0.54)
		let hue = Double(seed) * 0.14 + 0.04 + progress * 0.08 + typed * 0.08 + inherited * 0.08
		let color = Color(
			hue: hue.truncatingRemainder(dividingBy: 1),
			saturation: 0.54 + progress * 0.24 + typed,
			brightness: 1
		)
		context.stroke(
			path,
			with: .color(color.opacity(0.2 + progress * 0.64)),
			style: StrokeStyle(
				lineWidth: max(0.8, length * (0.09 - CGFloat(progress) * 0.045)),
				lineCap: .round,
				lineJoin: .round
			)
		)

		let children = selectedChildren(from: Array(node.children.values), limit: 7)
		guard !children.isEmpty else {
			drawTerminal(
				in: &context,
				node: node,
				origin: end,
				length: length,
				angle: angle,
				depth: depth,
				maxDepth: maxDepth,
				time: time,
				seed: seed,
				budget: &budget
			)
			return
		}

		let spread = min(CGFloat.pi * 0.82, 0.42 + CGFloat(children.count) * 0.14)
		for (index, child) in children.enumerated() {
			let childSeed = seedValue(for: child.name)
			let position = children.count == 1
				? CGFloat(sin(childSeed * .pi * 2)) * 0.16
				: (CGFloat(index) / CGFloat(children.count - 1) - 0.5)
			let sway = CGFloat(sin(time * 0.54 + childSeed * .pi * 2 + CGFloat(depth))) * 0.055
			let inheritanceBend = child.protonym == nil ? 0 : CGFloat(0.09)
			let typeBend = CGFloat(min(child.type.count, 5)) * 0.018
			let childAngle = angle + position * spread + sway + inheritanceBend - typeBend
			let childLength = length *
				(0.58 + childSeed * 0.12) *
				(children.count > 3 ? 0.9 : 1)

			drawNode(
				in: &context,
				node: child,
				origin: end,
				length: childLength,
				angle: childAngle,
				depth: depth + 1,
				maxDepth: maxDepth,
				time: time,
				seed: childSeed,
				budget: &budget
			)
		}
	}

	nonisolated private static func drawTerminal(
		in context: inout GraphicsContext,
		node: Lexicon.Graph.Node,
		origin: CGPoint,
		length: CGFloat,
		angle: CGFloat,
		depth: Int,
		maxDepth: Int,
		time: TimeInterval,
		seed: CGFloat,
		budget: inout Int
	) {
		guard depth + 1 < maxDepth, budget > 0 else {
			return
		}
		let twigs = 1 + (node.type.isEmpty ? 0 : 1) + (node.protonym == nil ? 0 : 1)
		for index in 0..<twigs {
			let offset = CGFloat(index) - CGFloat(twigs - 1) / 2
			let terminalNode = Lexicon.Graph.Node(name: "\(node.name)_terminal_\(index)")
			drawNode(
				in: &context,
				node: terminalNode,
				origin: origin,
				length: length * (0.38 + seed * 0.08),
				angle: angle + offset * 0.32 + CGFloat(sin(time + seed * 7)) * 0.04,
				depth: depth + 1,
				maxDepth: maxDepth,
				time: time,
				seed: seed + CGFloat(index) * 0.11,
				budget: &budget
			)
		}
	}

	nonisolated private static func selectedChildren(from children: [Lexicon.Graph.Node], limit: Int) -> [Lexicon.Graph.Node] {
		guard children.count > limit, limit > 1 else {
			return children
		}
		return (0..<limit).map { index in
			children[Int((Double(index) / Double(limit - 1)) * Double(children.count - 1))]
		}
	}

	nonisolated private static func seedValue(for string: String) -> CGFloat {
		let total = string.unicodeScalars.reduce(UInt32(0)) { result, scalar in
			result &* 31 &+ scalar.value
		}
		return CGFloat(total % 997) / 997
	}

	private struct Profile {
		var nodeCount = 0
		var inheritanceCount = 0
		var maxDepth = 1
		var seed: CGFloat

		init(_ graph: Lexicon.Graph) {
			seed = seedValue(for: graph.root.name)
			graph.root.traverse { id, _, node in
				nodeCount += 1
				inheritanceCount += node.type.count
				maxDepth = max(maxDepth, id.reduce(1) { depth, character in
					character == "." ? depth + 1 : depth
				})
			}
		}

		var nodeWeight: CGFloat {
			min(CGFloat(nodeCount) / 80, 1)
		}

		var inheritanceWeight: CGFloat {
			min(CGFloat(inheritanceCount) / 28, 1)
		}

		var depthWeight: CGFloat {
			min(CGFloat(maxDepth) / 10, 1)
		}
	}
}

#if DEBUG
#Preview("Fractal flare") {
	FractalFlareView(graph: FractalFlarePreview.graph)
		.frame(width: 256, height: 256)
		.padding()
}

#Preview("Fractal flare range") {
	HStack(spacing: 20) {
		FractalFlareView(graph: FractalFlarePreview.storyGraph)
			.frame(width: 220, height: 220)
		FractalFlareView(graph: FractalFlarePreview.systemGraph)
			.frame(width: 220, height: 220)
	}
	.padding()
}

#Preview("Tree flare") {
	LexiconTreeFlareView(graph: FractalFlarePreview.graph)
		.frame(width: 256, height: 256)
		.padding()
}

#Preview("Stats") {
	MindFlarePreviewLoader { fixture in
		StatsView()
			.environmentObject(fixture.editor)
	}
}

private enum FractalFlarePreview {
	static let graph = try! TaskPaper(source).decode()
	static let storyGraph = try! TaskPaper(storySource).decode()
	static let systemGraph = try! TaskPaper(systemSource).decode()

	private static let source =
		"mindflare:\n" +
		"\tdocument:\n" +
		"\t\tlexicon:\n" +
		"\t\t\tcompose:\n" +
		"\t\t\tconnections:\n" +
		"\t\t\tdiagnostics:\n" +
		"\t\teditor:\n" +
		"\t\t\tcanvas:\n" +
		"\t\t\tstats:\n" +
		"\t\t\t\tfractal:\n" +
		"\t\t\t\tpreview:\n" +
		"\t\timports:\n" +
		"\t\t\tlocal:\n" +
		"\t\t\tremote:\n" +
		"\tui:\n" +
		"\t\tflame:\n" +
		"\t\tsearch:\n" +
		"\t\trelationships:\n" +
		"\t\t\tinheritance:\n" +
		"\t\t\tconnections:\n" +
		"\ttype:\n" +
		"\t\tvisual:\n" +
		"\t\tmetadata:"

	private static let storySource =
		"book:\n" +
		"\tsentence:\n" +
		"\t\tword:\n" +
		"\t\t\tabout:\n" +
		"\t\t\talice:\n" +
		"\t\t\tgarden:\n" +
		"\t\t\tmirror:\n" +
		"\t\t\twonder:\n" +
		"\t\tphrase:\n" +
		"\t\t\tcurious:\n" +
		"\t\t\tlittle:\n" +
		"\t\t\trabbit:\n" +
		"\tchapter:\n" +
		"\t\topening:\n" +
		"\t\tpool:\n" +
		"\t\ttea:\n" +
		"\t\ttrial:\n" +
		"\tvoice:\n" +
		"\t\twhisper:\n" +
		"\t\tquestion:\n" +
		"\t\tanswer:"

	private static let systemSource =
		"blockchain:\n" +
		"\ttype:\n" +
		"\t\tprimitive:\n" +
		"\t\tentity:\n" +
		"\t\toperation:\n" +
		"\tcrypto:\n" +
		"\t+ blockchain.type.primitive\n" +
		"\t\thash:\n" +
		"\t\tsignature:\n" +
		"\tledger:\n" +
		"\t+ blockchain.type.entity\n" +
		"\t\tblock:\n" +
		"\t\t+ blockchain.type.entity\n" +
		"\t\t\theader:\n" +
		"\t\t\ttransaction:\n" +
		"\t\tconsensus:\n" +
		"\t\t+ blockchain.type.operation\n" +
		"\t\t\tvalidate:\n" +
		"\t\t\tfinalize:\n" +
		"\tnetwork:\n" +
		"\t+ blockchain.type.entity\n" +
		"\t\tpeer:\n" +
		"\t\tmempool:\n" +
		"\t\tgossip:"
}
#endif
