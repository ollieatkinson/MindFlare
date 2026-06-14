import Hope
import Lexicon
@testable import Library

final class LibraryTests: Hopes {
	
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
}
