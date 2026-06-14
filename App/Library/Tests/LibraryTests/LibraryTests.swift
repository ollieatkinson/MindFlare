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
}
