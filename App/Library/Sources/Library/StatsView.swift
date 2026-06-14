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

	let graph: Lexicon.Graph

	@State private var profile: Profile?

	var body: some View {
		GeometryReader { geometry in
			if let profile {
				TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
					Rectangle()
						.fill(.black)
						.colorEffect(Self.shader(
							profile: profile,
							size: geometry.size,
							time: timeline.date.timeIntervalSinceReferenceDate
						))
				}
			} else {
				Circle()
					.fill(.black.opacity(0.96))
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
		.task(id: graph.date) {
			let graph = graph
			profile = await Task.detached(priority: .userInitiated) {
				Profile(graph)
			}.value
		}
	}

	private static let shaderFunction = ShaderFunction(
		library: .bundle(.module),
		name: "mindFlareFractalFlame"
	)

	private static func shader(profile: Profile, size: CGSize, time: TimeInterval) -> Shader {
		Shader(
			function: shaderFunction,
			arguments: [
				.float2(Float(size.width), Float(size.height)),
				.float(Float(time.truncatingRemainder(dividingBy: 10_000))),
				.float4(Float(profile.seed), Float(profile.paletteSeed), Float(profile.shapeSeed), Float(profile.motionSeed)),
				.float4(Float(profile.foldSeed), Float(profile.horizontalBias), Float(profile.nodeWeight), Float(profile.depthWeight)),
				.float4(Float(profile.branchWeight), Float(profile.leafWeight), Float(profile.inheritanceWeight), Float(profile.metadataWeight)),
				.float4(Float(profile.connectionWeight), Float(profile.rhythmWeight), Float(profile.primaryHue), Float(profile.accentHue)),
				.float4(Float(profile.coreHue), Float(profile.lobeWeight), Float(profile.maxDepth), Float(profile.nodeCount)),
			]
		)
	}

	private struct Signature: Sendable {
		var seed: CGFloat
		var secondarySeed: CGFloat
		var tertiarySeed: CGFloat
		var depth: CGFloat
		var childWeight: CGFloat
		var inheritance: CGFloat
		var metadata: CGFloat
	}

	private struct Lobe: Sendable {
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

	private struct Profile: Sendable {
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

		var lobeWeight: CGFloat {
			min(CGFloat(lobes.count) / 12, 1)
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
