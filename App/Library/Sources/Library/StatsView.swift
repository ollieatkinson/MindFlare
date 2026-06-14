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
				.float(Float((time * animationSpeed).truncatingRemainder(dividingBy: 10_000))),
				.float4(Float(profile.seed), Float(profile.paletteSeed), Float(profile.shapeSeed), Float(profile.motionSeed)),
				.float4(Float(profile.foldSeed), Float(profile.horizontalBias), Float(profile.nodeWeight), Float(profile.depthWeight)),
				.float4(Float(profile.branchWeight), Float(profile.leafWeight), Float(profile.inheritanceWeight), Float(profile.metadataWeight)),
				.float4(Float(profile.connectionWeight), Float(profile.rhythmWeight), Float(profile.primaryHue), Float(profile.accentHue)),
				.float4(Float(profile.coreHue), Float(profile.lobeWeight), Float(profile.synonymWeight), Float(profile.nodeMass)),
			]
		)
	}

	private static let animationSpeed = 2.35

	private struct Profile: Sendable {
		var nodeCount = 0
		var synonymCount = 0
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

		init(_ graph: Lexicon.Graph) {
			var hasher = FlareHasher()
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
				synonymCount += node.protonym == nil ? 0 : 1
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
			}

			let fingerprint = hasher.finalized()
			seed = Self.unit(fingerprint)
			paletteSeed = Self.unit(Self.scramble(fingerprint &+ 1))
			shapeSeed = Self.unit(Self.scramble(fingerprint &+ 2))
			motionSeed = Self.unit(Self.scramble(fingerprint &+ 3))
			foldSeed = Self.unit(Self.scramble(fingerprint &+ 4))
			horizontalBias = Self.unit(Self.scramble(fingerprint &+ 5))
		}

		var nodeWeight: CGFloat {
			Self.logWeight(nodeCount, ceiling: 50_000)
		}

		var nodeMass: CGFloat {
			Self.logWeight(nodeCount, ceiling: 100_000)
		}

		var synonymWeight: CGFloat {
			Self.logWeight(synonymCount, ceiling: 10_000)
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
			min(branchWeight * 0.55 + connectionWeight * 0.25 + synonymWeight * 0.2, 1)
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
		.accessibilityLabel("Animated Lexicon tree flare")
		.task(id: graph.date) {
			let graph = graph
			profile = await Task.detached(priority: .userInitiated) {
				Profile(graph)
			}.value
		}
	}

	private static let shaderFunction = ShaderFunction(
		library: .bundle(.module),
		name: "mindFlareLexiconTree"
	)

	private static func shader(profile: Profile, size: CGSize, time: TimeInterval) -> Shader {
		Shader(
			function: shaderFunction,
			arguments: [
				.float2(Float(size.width), Float(size.height)),
				.float(Float(time.truncatingRemainder(dividingBy: 10_000))),
				.float4(Float(profile.seed), Float(profile.paletteSeed), Float(profile.shapeSeed), Float(profile.motionSeed)),
				.float4(Float(profile.nodeWeight), Float(profile.depthWeight), Float(profile.branchWeight), Float(profile.leafWeight)),
				.float4(Float(profile.inheritanceWeight), Float(profile.metadataWeight), Float(profile.connectionWeight), Float(profile.rhythmWeight)),
				.float4(Float(profile.maxDepth), Float(profile.nodeCount), Float(profile.breadthSeed), 0),
			]
		)
	}

	private struct Profile: Sendable {
		var nodeCount = 0
		var inheritanceCount = 0
		var connectionCount = 0
		var metadataCount = 0
		var leafCount = 0
		var maxBreadth = 0
		var maxDepth = 1
		var characterCount = 0
		var vowelCount = 0
		var seed: CGFloat = 0
		var paletteSeed: CGFloat = 0
		var shapeSeed: CGFloat = 0
		var motionSeed: CGFloat = 0
		var breadthSeed: CGFloat = 0

		init(_ graph: Lexicon.Graph) {
			var hasher = TreeHasher()
			hasher.mix("mindflare-metal-tree-v1")
			hasher.mix(graph.root.name)
			graph.root.traverse { id, _, node in
				let depth = id.reduce(1) { depth, character in
					character == "." ? depth + 1 : depth
				}
				let childCount = node.children.count
				let metadata = node.notes.count + node.comments.count + (node.defaultValue == nil ? 0 : 1)
				var nodeHasher = TreeHasher()
				nodeHasher.mix(id)
				nodeHasher.mix(node.name)
				nodeHasher.mix(depth)
				nodeHasher.mix(childCount)
				nodeHasher.mix(node.type.count)
				nodeHasher.mix(node.connections.count)
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
				let nodeHash = nodeHasher.finalized()
				hasher.mix(nodeHash)

				nodeCount += 1
				inheritanceCount += node.type.count
				connectionCount += node.connections.count
				metadataCount += metadata
				leafCount += childCount == 0 ? 1 : 0
				maxBreadth = max(maxBreadth, childCount)
				maxDepth = max(maxDepth, depth)
				characterCount += node.name.unicodeScalars.count
				vowelCount += node.name.unicodeScalars.reduce(0) { total, scalar in
					"aeiouAEIOU".unicodeScalars.contains(scalar) ? total + 1 : total
				}
			}

			let fingerprint = hasher.finalized()
			seed = Self.unit(fingerprint)
			paletteSeed = Self.unit(Self.scramble(fingerprint &+ 1))
			shapeSeed = Self.unit(Self.scramble(fingerprint &+ 2))
			motionSeed = Self.unit(Self.scramble(fingerprint &+ 3))
			breadthSeed = Self.unit(Self.scramble(fingerprint &+ 4))
		}

		var nodeWeight: CGFloat {
			Self.logWeight(nodeCount, ceiling: 50_000)
		}

		var inheritanceWeight: CGFloat {
			min(ratio(inheritanceCount, to: nodeCount) * 4, 1)
		}

		var connectionWeight: CGFloat {
			min(ratio(connectionCount, to: nodeCount) * 5, 1)
		}

		var metadataWeight: CGFloat {
			min(ratio(metadataCount, to: nodeCount) * 4, 1)
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

		private func ratio(_ value: Int, to total: Int) -> CGFloat {
			guard total > 0 else {
				return 0
			}
			return min(CGFloat(value) / CGFloat(total), 1)
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

	private struct TreeHasher {
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
