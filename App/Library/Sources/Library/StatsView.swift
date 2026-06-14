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
		.accessibilityLabel("Animated fractal flame shaped by the Lexicon")
	}

	nonisolated private static func draw(
		graph: Lexicon.Graph,
		in context: inout GraphicsContext,
		size: CGSize,
		time: TimeInterval
	) {
		let profile = Profile(graph)
		let scale = min(size.width, size.height)
		let center = CGPoint(x: size.width * 0.5, y: size.height * 0.53)
		let pulse = CGFloat(sin(time * 1.05 + Double(profile.seed) * Double.pi * 2)) * 0.5 + 0.5

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
			x: center.x - scale * (0.2 + profile.nodeWeight * 0.04),
			y: center.y + scale * 0.22,
			width: scale * (0.4 + profile.nodeWeight * 0.08),
			height: scale * (0.08 + profile.connectionWeight * 0.04)
		))
		context.fill(
			plate,
			with: .radialGradient(
				Gradient(colors: [
					Color(hue: 0.06, saturation: 0.82, brightness: 1).opacity(0.52 + Double(pulse) * 0.12),
					Color(hue: 0.1, saturation: 0.78, brightness: 0.9).opacity(0.16),
					.clear,
				]),
				center: CGPoint(x: center.x, y: center.y + scale * 0.26),
				startRadius: 0,
				endRadius: scale * 0.27
			)
		)

		let aura = Path(ellipseIn: CGRect(
			x: center.x - scale * 0.34,
			y: center.y - scale * 0.18,
			width: scale * 0.68,
			height: scale * 0.66
		))
		context.fill(
			aura,
			with: .radialGradient(
				Gradient(colors: [
					Color(hue: 0.94 + Double(profile.seed) * 0.04, saturation: 0.55, brightness: 1).opacity(0.2 + Double(profile.metadataWeight) * 0.08),
					Color(hue: 0.06 + Double(profile.inheritanceWeight) * 0.08, saturation: 0.74, brightness: 1).opacity(0.13 + Double(pulse) * 0.04),
					.clear,
				]),
				center: CGPoint(x: center.x, y: center.y + scale * 0.08),
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
		let sway = CGFloat(sin(time * 0.72 + Double(profile.seed) * Double.pi * 2))
		let breath = CGFloat(sin(time * 1.18 + Double(profile.depthWeight) * Double.pi))
		let fold = CGFloat(sin(time * 0.94 + Double(profile.inheritanceWeight) * 5.2))
		let height = scale * (0.48 + profile.depthWeight * 0.08 + breath * 0.018)
		let width = scale * (0.25 + profile.nodeWeight * 0.08)
		let lean = sway * scale * (0.022 + profile.connectionWeight * 0.025)

		let outer = flamePath(
			base: base,
			height: height,
			width: width,
			lean: lean,
			curl: fold * scale * 0.025,
			waist: 0.34 + profile.metadataWeight * 0.08
		)
		drawSoftLobe(
			in: &context,
			path: outer,
			base: base,
			tip: CGPoint(x: base.x + lean + fold * scale * 0.025, y: base.y - height),
			colors: [
				Color(hue: 0.01, saturation: 0.84, brightness: 1).opacity(0.42),
				Color(hue: 0.08, saturation: 0.62, brightness: 1).opacity(0.62),
				Color(hue: 0.14, saturation: 0.34, brightness: 1).opacity(0.76),
				Color.white.opacity(0.28),
			],
			blur: scale * 0.006
		)

		let left = flamePath(
			base: CGPoint(x: base.x - width * 0.12, y: base.y - scale * 0.015),
			height: height * (0.82 + profile.inheritanceWeight * 0.08),
			width: width * 0.62,
			lean: -width * (0.28 + profile.connectionWeight * 0.1) + sway * scale * 0.014,
			curl: -scale * (0.04 + profile.seed * 0.02) + fold * scale * 0.018,
			waist: 0.5
		)
		drawSoftLobe(
			in: &context,
			path: left,
			base: CGPoint(x: base.x - width * 0.12, y: base.y),
			tip: CGPoint(x: base.x - width * 0.34 + sway * scale * 0.014, y: base.y - height * 0.78),
			colors: [
				Color(hue: 0.78, saturation: 0.32, brightness: 1).opacity(0.24),
				Color(hue: 0.94, saturation: 0.5, brightness: 1).opacity(0.38),
				Color(hue: 0.08, saturation: 0.46, brightness: 1).opacity(0.24),
			],
			blur: scale * 0.003
		)

		let right = flamePath(
			base: CGPoint(x: base.x + width * 0.1, y: base.y - scale * 0.005),
			height: height * (0.68 + profile.metadataWeight * 0.1),
			width: width * (0.56 + profile.connectionWeight * 0.08),
			lean: width * (0.2 + profile.seed * 0.14) + sway * scale * 0.012,
			curl: scale * 0.05 + fold * scale * 0.016,
			waist: 0.42
		)
		drawSoftLobe(
			in: &context,
			path: right,
			base: CGPoint(x: base.x + width * 0.1, y: base.y),
			tip: CGPoint(x: base.x + width * 0.28 + sway * scale * 0.012, y: base.y - height * 0.58),
			colors: [
				Color(hue: 0.91, saturation: 0.88, brightness: 1).opacity(0.5),
				Color(hue: 0.98, saturation: 0.72, brightness: 1).opacity(0.58),
				Color(hue: 0.08, saturation: 0.62, brightness: 1).opacity(0.45),
			],
			blur: scale * 0.003
		)

		let bloom = lowerBloomPath(
			center: CGPoint(
				x: base.x + width * (0.18 + sway * 0.04),
				y: base.y - height * 0.16
			),
			width: width * (0.66 + profile.connectionWeight * 0.08),
			height: height * (0.3 + profile.metadataWeight * 0.05),
			lean: sway * width * 0.1
		)
		drawSoftLobe(
			in: &context,
			path: bloom,
			base: CGPoint(x: base.x + width * 0.18, y: base.y),
			tip: CGPoint(x: base.x + width * 0.32, y: base.y - height * 0.34),
			colors: [
				Color(hue: 0.94, saturation: 0.62, brightness: 1).opacity(0.36),
				Color(hue: 0.02, saturation: 0.8, brightness: 1).opacity(0.48),
				Color(hue: 0.1, saturation: 0.62, brightness: 1).opacity(0.3),
			],
			blur: scale * 0.004
		)

		let core = flamePath(
			base: CGPoint(x: base.x + width * 0.02, y: base.y - scale * 0.01),
			height: height * (0.72 + profile.inheritanceWeight * 0.07),
			width: width * 0.42,
			lean: width * 0.08 + sway * scale * 0.016,
			curl: fold * scale * 0.035,
			waist: 0.3
		)
		drawSoftLobe(
			in: &context,
			path: core,
			base: CGPoint(x: base.x, y: base.y),
			tip: CGPoint(x: base.x + width * 0.08, y: base.y - height * 0.68),
			colors: [
				Color.white.opacity(0.58),
				Color(hue: 0.12, saturation: 0.52, brightness: 1).opacity(0.74),
				Color(hue: 0.96, saturation: 0.58, brightness: 1).opacity(0.52),
			],
			blur: 0
		)

		drawFlameFolds(
			in: &context,
			base: base,
			height: height,
			width: width,
			sway: sway,
			fold: fold,
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
		let foldCount = max(7, min(15, profile.maxDepth + profile.connectionCount + 5))
		for index in 0..<foldCount {
			let progress = CGFloat(index) / CGFloat(max(foldCount - 1, 1))
			let seed = profile.signatures.isEmpty
				? profile.seed
				: profile.signatures[index % profile.signatures.count].seed
			let side = progress - 0.5
			let baseOffset = side * width * 0.28
			let topOffset = sin(seed * .pi * 2 + CGFloat(time) * 0.42) * width * 0.22 + sway * width * 0.12
			let top = CGPoint(
				x: base.x + topOffset + fold * width * 0.08,
				y: base.y - height * (0.68 + seed * 0.2)
			)
			var ridge = Path()
			ridge.move(to: CGPoint(x: base.x + baseOffset, y: base.y - height * 0.02))
			ridge.addCurve(
				to: top,
				control1: CGPoint(
					x: base.x + side * width * 0.72,
					y: base.y - height * 0.22
				),
				control2: CGPoint(
					x: base.x + topOffset - side * width * 0.28,
					y: base.y - height * 0.48
				)
			)
			let warmth = Double(0.04 + seed * 0.08 + profile.metadataWeight * 0.05)
			context.stroke(
				ridge,
				with: .linearGradient(
					Gradient(colors: [
						Color(hue: warmth, saturation: 0.62, brightness: 1).opacity(0.08),
						Color.white.opacity(0.18 + Double(seed) * 0.08),
						Color(hue: 0.92, saturation: 0.42, brightness: 1).opacity(0.04),
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
	}

	private struct Profile {
		var nodeCount = 0
		var inheritanceCount = 0
		var connectionCount = 0
		var metadataCount = 0
		var maxDepth = 1
		var seed: CGFloat
		var signatures: [Signature] = []

		init(_ graph: Lexicon.Graph) {
			seed = seedValue(for: graph.root.name)
			graph.root.traverse { id, _, node in
				let depth = id.reduce(1) { depth, character in
					character == "." ? depth + 1 : depth
				}
				nodeCount += 1
				inheritanceCount += node.type.count + (node.protonym == nil ? 0 : 1)
				connectionCount += node.connections.count
				metadataCount += node.notes.count + node.comments.count + (node.defaultValue == nil ? 0 : 1)
				maxDepth = max(maxDepth, depth)
				signatures.append(.init(seed: seedValue(for: id)))
			}
		}

		var nodeWeight: CGFloat {
			min(CGFloat(nodeCount) / 80, 1)
		}

		var inheritanceWeight: CGFloat {
			min(CGFloat(inheritanceCount) / 28, 1)
		}

		var connectionWeight: CGFloat {
			min(CGFloat(connectionCount) / 12, 1)
		}

		var metadataWeight: CGFloat {
			min(CGFloat(metadataCount) / 32, 1)
		}

		var depthWeight: CGFloat {
			min(CGFloat(maxDepth) / 10, 1)
		}
	}

	nonisolated private static func seedValue(for string: String) -> CGFloat {
		let total = string.unicodeScalars.reduce(UInt32(0)) { result, scalar in
			result &* 31 &+ scalar.value
		}
		return CGFloat(total % 997) / 997
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
}
#endif
