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

	var body: some View {
		VStack(alignment: .center) {
			FractalFlareView(graph: my.snapshot.graph)
				.frame(width: 256, height: 256)
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
		.accessibilityLabel("Animated fractal flare")
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
			brightness: 1.0
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
		let twigs = 1 + (node.type.count > 0 ? 1 : 0) + (node.protonym == nil ? 0 : 1)
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
