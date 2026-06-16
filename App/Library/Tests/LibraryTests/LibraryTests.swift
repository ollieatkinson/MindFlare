import Hope
import Lexicon
@testable import Library

final class LibraryTests: Hopes {

	func testSnapshotEqualityUsesStructuralTaskPaperSemantics() throws {
		func document(
			date: TimeInterval,
			imports: [String] = [],
			connections: [String] = []
		) -> Lexicon.Document {
			Lexicon.Document(
				date: Date(timeIntervalSince1970: date),
				roots: [
					"root": Lexicon.Graph.Node(
						name: "root",
						children: [
							"child": Lexicon.Graph.Node(
								name: "child",
								connections: connections.map(Lexicon.Import.init)
							),
						]
					),
				],
				imports: imports.map(Lexicon.Import.init)
			)
		}

		let stableGraph = Lexicon.Graph(
			root: Lexicon.Graph.Node(name: "root"),
			date: Date(timeIntervalSince1970: 1)
		)
		let lhs = Document.Snapshot(
			document: document(
				date: 2,
				imports: [
					"./b.lexicon",
					"./a.lexicon",
				],
				connections: [
					"./z.lexicon",
					"./a.lexicon",
				]
			),
			composed: document(date: 3),
			graph: stableGraph
		)
		let rhs = Document.Snapshot(
			document: document(
				date: 4,
				imports: [
					"./a.lexicon",
					"./b.lexicon",
				],
				connections: [
					"./a.lexicon",
					"./z.lexicon",
				]
			),
			composed: document(date: 5),
			graph: stableGraph
		)

		XCTAssertEqual(lhs, rhs)
	}

	func testConnectedLexiconCompositionResolvesLocalFileConnections() throws {
		let directory = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

		let root = directory.appendingPathComponent("connected-root.taskpaper")
		try """
			organization:
				products:
				@ ./products.lexicon
					local_term:
				engineering:
				@ ./engineering.lexicon
					local_term:
			""".write(to: root, atomically: true, encoding: .utf8)
		try """
			products:
				product:
					roadmap:
				glossary:
					term:
			""".write(to: directory.appendingPathComponent("products.lexicon"), atomically: true, encoding: .utf8)
		try """
			engineering:
				runtime:
					event:
					lexicon:
				quality:
					test:
			""".write(to: directory.appendingPathComponent("engineering.lexicon"), atomically: true, encoding: .utf8)

		let document = try TaskPaper(Data(contentsOf: root)).decodeDocument()
		let snapshot = try Document.Snapshot(document: document)
			.composing(relativeTo: root)
		let organization = try snapshot.composed.roots["organization"].try()
		let products = try organization.children["products"].try()
		let engineering = try organization.children["engineering"].try()

		XCTAssertEqual(snapshot.compositionDiagnostics, [])
		XCTAssertEqual(snapshot.graph.root.name, "organization")
		XCTAssertEqual(products.connections, [])
		XCTAssertEqual(products.children.keys.sorted(), [
			"glossary",
			"local_term",
			"product",
		])
		XCTAssertEqual(engineering.connections, [])
		XCTAssertEqual(engineering.children.keys.sorted(), [
			"local_term",
			"quality",
			"runtime",
		])
	}

	func testConnectedLexiconCompositionResolvesSubfolderAndParentRelativeConnections() throws {
		let directory = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let rootDirectory = directory.appendingPathComponent("Root", isDirectory: true)
		let sharedDirectory = directory.appendingPathComponent("Shared", isDirectory: true)
		let importsDirectory = rootDirectory.appendingPathComponent("Imports", isDirectory: true)
		defer { try? FileManager.default.removeItem(at: directory) }

		try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
		try FileManager.default.createDirectory(at: sharedDirectory, withIntermediateDirectories: true)
		try FileManager.default.createDirectory(at: importsDirectory, withIntermediateDirectories: true)

		let root = rootDirectory.appendingPathComponent("connected-root.taskpaper")
		try """
			organization:
				products:
				@ ../Shared/products.lexicon
					local_term:
				engineering:
				@ ./Imports/engineering.lexicon
					local_term:
			""".write(to: root, atomically: true, encoding: .utf8)
		try """
			products:
				product:
					roadmap:
			""".write(to: sharedDirectory.appendingPathComponent("products.lexicon"), atomically: true, encoding: .utf8)
		try """
			engineering:
				runtime:
					event:
			""".write(to: importsDirectory.appendingPathComponent("engineering.lexicon"), atomically: true, encoding: .utf8)

		let document = try TaskPaper(Data(contentsOf: root)).decodeDocument()
		let snapshot = try Document.Snapshot(document: document)
			.composing(relativeTo: root)
		let organization = try snapshot.composed.roots["organization"].try()
		let products = try organization.children["products"].try()
		let engineering = try organization.children["engineering"].try()

		XCTAssertEqual(snapshot.compositionDiagnostics, [])
		XCTAssertEqual(products.connections, [])
		XCTAssertEqual(products.children.keys.sorted(), [
			"local_term",
			"product",
		])
		XCTAssertEqual(engineering.connections, [])
		XCTAssertEqual(engineering.children.keys.sorted(), [
			"local_term",
			"runtime",
		])
	}

	func testSnapshotReportsConnectionsCoveringSelectedPaths() throws {
		let document = try TaskPaper("""
			organization:
				products:
				@ ../Shared/products.lexicon
					local_term:
				engineering:
				@ ./Imports/engineering.lexicon
					local_term:
			""").decodeDocument()

		let snapshot = try Document.Snapshot(document: document)
		let anchorConnections = snapshot.connections(covering: "organization.engineering")
		let descendantConnections = snapshot.connections(covering: "organization.engineering.runtime")

		XCTAssertEqual(anchorConnections.map(\.path), ["organization.engineering"])
		XCTAssertEqual(anchorConnections.map(\.import.reference), ["./Imports/engineering.lexicon"])
		XCTAssertEqual(anchorConnections.map(\.lexicon), ["engineering.lexicon"])
		XCTAssertEqual(descendantConnections.map(\.path), ["organization.engineering"])
	}

	func testSearchModelReturnsFullHybridResultsWithMetadataEvidence() async throws {
		let document = try TaskPaper("""
			commerce:
				capability:
					receipt:
				checkout:
				+ commerce.capability
					# Checkout support comments mention refunds.
					> Refund review status appears in support workflows.
			""").decodeDocument()
		let noteResults = await LexiconSearchModel.results(for: "refund review", in: document, limit: 10)
		let commentResults = await LexiconSearchModel.results(for: "support comments", in: document, limit: 10)
		let noteMatch = try noteResults.first { $0.id == "commerce.checkout" }.try()
		let commentMatch = try commentResults.first { $0.id == "commerce.checkout" }.try()

		XCTAssertEqual(noteResults.first?.id, "commerce.checkout")
		XCTAssertEqual(commentResults.first?.id, "commerce.checkout")
		XCTAssert(noteMatch.matches.contains { $0.field == .note })
		XCTAssert(commentMatch.matches.contains { $0.field == .comment })
		XCTAssertEqual(noteMatch.notes, ["Refund review status appears in support workflows."])
		XCTAssertEqual(commentMatch.comments, ["Checkout support comments mention refunds."])
	}

	func testSearchModelUsesFullScopeResolvedContext() async throws {
		let document = try TaskPaper("""
			commerce:
				capability:
					receipt:
				checkout:
				+ commerce.capability
			""").decodeDocument()
		let results = await LexiconSearchModel.results(for: "receipt", in: document, limit: 20)
		let checkout = try results.first { $0.id == "commerce.checkout" }.try()

		XCTAssert(results.map(\.id).contains("commerce.checkout.receipt"))
		XCTAssert(checkout.matches.contains { $0.field == .contextChild })
	}

	func testPropertiesSurfaceLexiconMetadata() async throws {
		let document = try TaskPaper("""
			# File comment.
			> File note.
			commerce:
				checkout:
				? {"enabled":true}
					# Implementation comment.
					> Product note.
			""").decodeDocument()
		let lexicon = try await Lexicon.from(document)
		let rootUI = await CLI(lexicon.root).ui(context: .viewing)
		let checkout = try await lexicon["commerce.checkout"].try()
		let checkoutUI = await CLI(checkout).ui(context: .viewing)

		XCTAssertEqual(rootUI.properties.documentNotes, ["File note."])
		XCTAssertEqual(rootUI.properties.documentComments, ["File comment."])
		XCTAssertEqual(checkoutUI.properties.documentNotes, [])
		XCTAssertEqual(checkoutUI.properties.documentComments, [])
		XCTAssertEqual(checkoutUI.properties.notes, ["Product note."])
		XCTAssertEqual(checkoutUI.properties.comments, ["Implementation comment."])
		XCTAssertEqual(checkoutUI.properties.defaultValue, .literal(.object(["enabled": .bool(true)])))
	}

	func testImportAccessRequestNamesMissingFileAndGrantFolder() {
		let request = SecurityScopedImportAccess.Request(
			fileURL: URL(fileURLWithPath: "/Users/example/Lexicons/shared-commerce.lexicon"),
			importReference: "./shared-commerce.lexicon",
			underlyingDescription: "The file could not be opened because you do not have permission to view it."
		)

		XCTAssertEqual(request.fileName, "shared-commerce.lexicon")
		XCTAssertEqual(request.folderPath, "/Users/example/Lexicons")
		XCTAssertEqual(request.permissionTitle, "Permission needed for shared-commerce.lexicon")
		XCTAssertEqual(
			request.permissionDetail,
			"Choose /Users/example/Lexicons, or a parent folder that contains all related Lexicon files."
		)
		XCTAssertEqual(
			request.errorDescription,
			"MindFlare needs permission to read imported Lexicon file \"shared-commerce.lexicon\"."
		)
	}

	func testEmptyInputSiblingSelectionClimbsToNearestVisibleLevelWithChoices() async throws {
		let root = await Self.historyRoot()
		let current = try await root.lexicon["root.b.only"].try()
		let cli = await CLI(current)

		let next = await cli.selectingSibling(offset: 1)
		let previous = await cli.selectingSibling(offset: -1)

		XCTAssertEqual(next.lemma.id, "root.c")
		XCTAssertEqual(previous.lemma.id, "root.a")
		XCTAssertEqual(next.root.id, "root")
	}

	func testEmptyInputSiblingSelectionRespectsNestedBrowserRoot() async throws {
		let root = await Self.historyRoot()
		let browserRoot = try await root.lexicon["root.b"].try()
		let current = try await root.lexicon["root.b.only"].try()
		let cli = await CLI(current, root: browserRoot)

		let next = await cli.selectingSibling(offset: 1)
		let previous = await cli.selectingSibling(offset: -1)

		XCTAssertEqual(next.lemma.id, "root.b.only")
		XCTAssertEqual(previous.lemma.id, "root.b.only")
		XCTAssertEqual(next.root.id, "root.b")
	}

	func testEmptyInputSiblingSelectionHandlesLargeSiblingLists() async throws {
		let root = await Self.largeSiblingRoot(count: 1_500)
		let current = try await root.lexicon["root.n_0500"].try()
		let cli = await CLI(current)

		let next = await cli.selectingSibling(offset: 1)
		let previous = await cli.selectingSibling(offset: -1)

		XCTAssertEqual(next.lemma.id, "root.n_0501")
		XCTAssertEqual(previous.lemma.id, "root.n_0499")
	}

	func testEmptyInputSiblingSelectionSkipsDuplicateInheritedRows() async throws {
		let root = await Self.typedSiblingRoot()
		let current = try await root.lexicon["root.item.shared"].try()
		let cli = await CLI(current)

		let next = await cli.selectingSibling(offset: 1)

		XCTAssertEqual(next.lemma.id, "root.item.zed")
	}

	func testColumnsWindowLargeSiblingListsAroundSelection() async throws {
		let root = await Self.largeSiblingRoot(count: 1_500)
		let current = try await root.lexicon["root.n_0500"].try()
		let cli = await CLI(current)
		let ui = await cli.ui(context: .viewing)
		let rootRows = ui.columns[1].sections.flatMap(\.rows)

		XCTAssertLessThan(rootRows.count, 600)
		XCTAssert(rootRows.contains { $0.id == "root.n_0000" })
		XCTAssert(rootRows.contains { $0.id == "root.n_0500" })
		XCTAssert(rootRows.contains { $0.id == "root.n_1499" })
		XCTAssertFalse(rootRows.contains { $0.id == "root.n_1000" })
	}

	func testHistoryBackwardsKeepsForwardStack() async throws {
		let root = await Self.historyRoot()
		let current = try await root.lexicon["root.b"].try()
		let cli = await CLI(current)

		let result = await Editor.Object.backwards(
			cli: cli,
			back: ["root", "root.a", "root.b"],
			forward: ["root.c"]
		)

		XCTAssertEqual(result.cli?.lemma.id, "root.a")
		XCTAssertEqual(result.back, ["root", "root.a"])
		XCTAssertEqual(result.forward, ["root.c", "root.b"])
	}

	func testHistoryBackwardsPrunesDeletedNodes() async throws {
		let root = await Self.historyRoot()
		let current = try await root.lexicon["root.b"].try()
		let cli = await CLI(current)

		let result = await Editor.Object.backwards(
			cli: cli,
			back: ["root", "root.deleted", "root.b"],
			forward: []
		)

		XCTAssertEqual(result.cli?.lemma.id, "root")
		XCTAssertEqual(result.back, ["root"])
		XCTAssertEqual(result.forward, ["root.b"])
	}

	@LexiconActor private static func historyRoot() -> Lemma {
		Lexicon.from(
			Lexicon.Graph(
				root: Lexicon.Graph.Node(
					name: "root",
					children: [
						"a": Lexicon.Graph.Node(name: "a"),
						"b": Lexicon.Graph.Node(
							name: "b",
							children: [
								"only": Lexicon.Graph.Node(name: "only"),
							]
						),
						"c": Lexicon.Graph.Node(name: "c"),
					]
				)
			)
		)
		.root
	}

	@LexiconActor private static func typedSiblingRoot() -> Lemma {
		Lexicon.from(
			Lexicon.Graph(
				root: Lexicon.Graph.Node(
					name: "root",
					children: [
						"item": Lexicon.Graph.Node(
							name: "item",
							children: [
								"shared": Lexicon.Graph.Node(name: "shared"),
							],
							type: ["root.type"]
						),
						"type": Lexicon.Graph.Node(
							name: "type",
							children: [
								"shared": Lexicon.Graph.Node(name: "shared"),
								"zed": Lexicon.Graph.Node(name: "zed"),
							]
						),
					]
				)
			)
		)
		.root
	}

	@LexiconActor private static func largeSiblingRoot(count: Int) -> Lemma {
		Lexicon.from(
			Lexicon.Graph(
				root: Lexicon.Graph.Node(
					name: "root",
					children: Dictionary(uniqueKeysWithValues: (0..<count).map { index in
						let name = zeroPaddedName(index)
						return (name, Lexicon.Graph.Node(name: name))
					})
				)
			)
		)
		.root
	}

	private static func zeroPaddedName(_ index: Int) -> String {
		let value = String(index)
		return "n_" + String(repeating: "0", count: max(0, 4 - value.count)) + value
	}
}
